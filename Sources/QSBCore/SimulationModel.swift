import Foundation

public enum SimulationRepresentation: String, Codable, Sendable { case matrix, graphic }
public enum SimulationComponentKind: String, Codable, Sendable { case customer = "C", server = "S", queue = "Q", gate = "G" }
public enum SimulationDistributionKind: String, Codable, Sendable { case constant, exponential, normal, uniform, triangular }

public struct SimulationDistribution: Codable, Equatable, Sendable {
    public let kind: SimulationDistributionKind
    public let parameters: [Double]
    public init(kind: SimulationDistributionKind, parameters: [Double]) { self.kind = kind; self.parameters = parameters }
}

public struct SimulationRoute: Codable, Equatable, Sendable {
    public let target: String
    public let probability: Double
    public let transferTime: Double
    public init(target: String, probability: Double = 1, transferTime: Double = 0) { self.target = target; self.probability = probability; self.transferTime = transferTime }
}

public struct SimulationServiceRule: Codable, Equatable, Sendable {
    public let entityType: String
    public let distribution: SimulationDistribution
    public init(entityType: String, distribution: SimulationDistribution) { self.entityType = entityType; self.distribution = distribution }
}

public struct SimulationComponent: Codable, Equatable, Sendable {
    public let name: String
    public let kind: SimulationComponentKind
    public let routes: [SimulationRoute]
    public let inputRule: String?
    public let outputRule: String?
    public let queueDiscipline: String?
    public let queueCapacity: Int?
    public let attributeValue: Double?
    public let interarrivalTime: SimulationDistribution?
    public let batchSize: SimulationDistribution?
    public let serviceRules: [SimulationServiceRule]

    public init(name: String, kind: SimulationComponentKind, routes: [SimulationRoute], inputRule: String? = nil, outputRule: String? = nil, queueDiscipline: String? = nil, queueCapacity: Int? = nil, attributeValue: Double? = nil, interarrivalTime: SimulationDistribution? = nil, batchSize: SimulationDistribution? = nil, serviceRules: [SimulationServiceRule] = []) {
        self.name = name; self.kind = kind; self.routes = routes; self.inputRule = inputRule; self.outputRule = outputRule; self.queueDiscipline = queueDiscipline; self.queueCapacity = queueCapacity; self.attributeValue = attributeValue; self.interarrivalTime = interarrivalTime; self.batchSize = batchSize; self.serviceRules = serviceRules
    }
}

public struct SimulationModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let representation: SimulationRepresentation
    public let components: [SimulationComponent]
    public init(title: String, timeUnit: String, representation: SimulationRepresentation, components: [SimulationComponent]) { self.title = title; self.timeUnit = timeUnit; self.representation = representation; self.components = components }
}

public struct SimulationQueueMetrics: Codable, Equatable, Sendable { public let name: String; public let averageLength: Double; public let maximumLength: Int; public let entered: Int; public let rejected: Int }
public struct SimulationServerMetrics: Codable, Equatable, Sendable { public let name: String; public let completed: Int; public let utilization: Double }
public struct SimulationSolution: Codable, Equatable, Sendable {
    public let horizon: Double; public let seed: Int; public let generatedEntities: Int; public let completedEntities: Int
    public let queueMetrics: [SimulationQueueMetrics]; public let serverMetrics: [SimulationServerMetrics]
}
public struct SimulationSolutionDocument: Codable, Equatable, Sendable { public let backend: SolverRunMetadata; public let model: SimulationModel; public let solution: SimulationSolution }
public struct SimulationValidationDocument: Codable, Equatable, Sendable { public let model: SimulationModel; public let report: ValidationReport; public init(model: SimulationModel, report: ValidationReport) { self.model = model; self.report = report } }

public enum SimulationError: Error, CustomStringConvertible {
    case invalidModel(String), unsupportedDistribution(String)
    public var description: String { switch self { case .invalidModel(let text): "Invalid simulation model: \(text)"; case .unsupportedDistribution(let text): "Unsupported simulation distribution: \(text)" } }
}

public enum WinQSBSimulationParser {
    public static func parse(from data: Data) throws -> SimulationModel {
        guard let text = String(data: data, encoding: .utf8) ?? data.legacyLatin1String else { throw SimulationError.invalidModel("file is not text") }
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 3 else { throw SimulationError.invalidModel("missing header or components") }
        let header = fields(lines[0]); guard header.count >= 5, header[0].uppercased() == "QSS", let count = Int(header[3]) else { throw SimulationError.invalidModel("invalid QSS header") }
        let representation: SimulationRepresentation = header[4].lowercased() == "graphic" ? .graphic : .matrix
        guard lines.count >= count + 2 else { throw SimulationError.invalidModel("expected \(count) component rows") }
        var components: [SimulationComponent] = []
        for row in lines[2..<(2 + count)] {
            var columns = fields(row); if columns.count < 11 { columns += Array(repeating: "", count: 11 - columns.count) }
            guard let kind = SimulationComponentKind(rawValue: columns[1].uppercased()) else { throw SimulationError.invalidModel("unknown component type \(columns[1])") }
            components.append(SimulationComponent(name: columns[0], kind: kind, routes: try routes(columns[2]), inputRule: optional(columns[3]), outputRule: optional(columns[4]), queueDiscipline: optional(columns[5]), queueCapacity: Int(columns[6]), attributeValue: Double(columns[7]), interarrivalTime: try distribution(columns[8]), batchSize: try distribution(columns[9]), serviceRules: try serviceRules(columns[10])))
        }
        return SimulationModel(title: header[1], timeUnit: header[2], representation: representation, components: components)
    }

    private static func fields(_ line: String) -> [String] { line.split(separator: "\t", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    private static func optional(_ value: String) -> String? { value.isEmpty ? nil : value }
    private static func routes(_ value: String) throws -> [SimulationRoute] { try value.split(separator: ",").map { item in let p = item.split(separator: "/", omittingEmptySubsequences: false).map(String.init); guard let target = p.first, !target.isEmpty else { throw SimulationError.invalidModel("empty route") }; return SimulationRoute(target: target, probability: p.count > 1 ? (Double(p[1]) ?? 1) : 1, transferTime: p.count > 2 ? (Double(p[2]) ?? 0) : 0) } }
    private static func serviceRules(_ value: String) throws -> [SimulationServiceRule] { try value.split(separator: ",").map { item in var p = item.split(separator: "/", omittingEmptySubsequences: false).map(String.init); guard !p.isEmpty else { throw SimulationError.invalidModel("empty service rule") }; let entity = p.removeFirst(); guard let d = try distribution(p.joined(separator: "/")) else { throw SimulationError.invalidModel("missing service distribution") }; return SimulationServiceRule(entityType: entity, distribution: d) } }
    private static func distribution(_ value: String) throws -> SimulationDistribution? {
        if value.isEmpty { return nil }; let p = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init); guard let name = p.first else { return nil }
        let kind: SimulationDistributionKind
        switch name.lowercased() { case "constant", "const", "cons": kind = .constant; case "exp": kind = .exponential; case "normal": kind = .normal; case "uniform": kind = .uniform; case "tri": kind = .triangular; default: throw SimulationError.unsupportedDistribution(name) }
        return SimulationDistribution(kind: kind, parameters: p.dropFirst().compactMap(Double.init))
    }
}

public enum SimulationValidator {
    public static func diagnostics(for model: SimulationModel) -> [ValidationDiagnostic] {
        var result: [ValidationDiagnostic] = []; let names = Set(model.components.map { $0.name.lowercased() })
        if names.count != model.components.count { result.append(error("duplicate", "Component names must be unique.", "components")) }
        for (index, component) in model.components.enumerated() {
            for route in component.routes where !names.contains(route.target.lowercased()) { result.append(error("route", "Route target '\(route.target)' does not exist.", "components[\(index)].routes")) }
            if component.kind != .queue && component.routes.reduce(0, { $0 + $1.probability }) > 1.000001 { result.append(error("probability", "Route probabilities exceed one.", "components[\(index)].routes")) }
            if component.kind == .customer && (component.interarrivalTime == nil || component.batchSize == nil) { result.append(error("source", "Customer sources require interarrival and batch distributions.", "components[\(index)]")) }
            if component.kind == .queue && (component.queueCapacity ?? 0) <= 0 { result.append(error("capacity", "Queues require positive capacity.", "components[\(index)].queueCapacity")) }
            if component.kind == .server && component.serviceRules.isEmpty { result.append(error("service", "Servers require a service rule.", "components[\(index)].serviceRules")) }
        }
        if result.isEmpty { result.append(ValidationDiagnostic(severity: .info, code: "simulation.valid", message: "Simulation model is valid")) }; return result
    }
    public static func validate(_ model: SimulationModel) throws { let errors = diagnostics(for: model).filter { $0.severity == .error }; if !errors.isEmpty { throw SimulationError.invalidModel(errors.map(\.message).joined(separator: " ")) } }
    private static func error(_ code: String, _ message: String, _ path: String) -> ValidationDiagnostic { ValidationDiagnostic(severity: .error, code: "simulation.\(code)", message: message, path: path) }
}

public enum DiscreteEventSimulationSolver {
    public static func solve(_ model: SimulationModel, horizon: Double = 1_000, seed: Int = 1) throws -> SimulationSolution {
        try SimulationValidator.validate(model); var state = Engine(model: model, horizon: horizon, seed: UInt64(bitPattern: Int64(seed))); return state.run(seed: seed)
    }

    private struct Entity { let type: String; let entered: Double }
    private enum EventKind { case source(Int), enter(String, Entity), complete(Int, [Entity]) }
    private struct Event { let time: Double; let serial: Int; let kind: EventKind }
    private struct Engine {
        let model: SimulationModel; let horizon: Double; var rng: RNG; var events: [Event] = []; var serial = 0; var queues: [String: [Entity]] = [:]; var queueArea: [String: Double] = [:]; var queueMaximum: [String: Int] = [:]; var queueEntered: [String: Int] = [:]; var rejected: [String: Int] = [:]; var busy: Set<Int> = []; var busyTime: [Int: Double] = [:]; var serverCompleted: [Int: Int] = [:]; var generated = 0; var completed = 0; var lastTime = 0.0
        init(model: SimulationModel, horizon: Double, seed: UInt64) { self.model = model; self.horizon = horizon; self.rng = RNG(state: seed == 0 ? 1 : seed); for c in model.components where c.kind == .queue { queues[c.name.lowercased()] = [] } }
        mutating func run(seed: Int) -> SimulationSolution {
            for (i, c) in model.components.enumerated() where c.kind == .customer { schedule(0, .source(i)) }
            while let event = pop(), event.time <= horizon { integrate(to: event.time); switch event.kind { case .source(let i): source(i, at: event.time); case .enter(let target, let entity): enter(target, entity, at: event.time); case .complete(let i, let entities): finish(i, entities, at: event.time) } }
            integrate(to: horizon)
            let qm = model.components.filter { $0.kind == .queue }.map { c in let key = c.name.lowercased(); return SimulationQueueMetrics(name: c.name, averageLength: (queueArea[key] ?? 0) / horizon, maximumLength: queueMaximum[key] ?? 0, entered: queueEntered[key] ?? 0, rejected: rejected[key] ?? 0) }
            let sm = model.components.enumerated().filter { $0.element.kind == .server }.map { i, c in SimulationServerMetrics(name: c.name, completed: serverCompleted[i] ?? 0, utilization: min(1, (busyTime[i] ?? 0) / horizon)) }
            return SimulationSolution(horizon: horizon, seed: seed, generatedEntities: generated, completedEntities: completed, queueMetrics: qm, serverMetrics: sm)
        }
        mutating func source(_ index: Int, at time: Double) { let c = model.components[index]; let batch = max(1, Int(sample(c.batchSize!).rounded())); generated += batch; for _ in 0..<batch { route(from: c, entities: [Entity(type: c.name, entered: time)], at: time) }; let next = time + max(1e-9, sample(c.interarrivalTime!)); schedule(next, .source(index)) }
        mutating func enter(_ target: String, _ entity: Entity, at time: Double) { guard let index = model.components.firstIndex(where: { $0.name.caseInsensitiveCompare(target) == .orderedSame }) else { return }; let c = model.components[index]; if c.kind == .queue { let key = c.name.lowercased(); if queues[key]!.count >= (c.queueCapacity ?? .max) { rejected[key, default: 0] += 1; return }; queues[key]!.append(entity); queueEntered[key, default: 0] += 1; queueMaximum[key] = max(queueMaximum[key] ?? 0, queues[key]!.count); dispatch(at: time) } else { completed += 1 } }
        mutating func dispatch(at time: Double) { var changed = true; while changed { changed = false; for (i, server) in model.components.enumerated() where server.kind == .server && !busy.contains(i) { let inputNames = model.components.filter { $0.kind == .queue && $0.routes.contains(where: { $0.target.caseInsensitiveCompare(server.name) == .orderedSame }) }.map { $0.name.lowercased() }; let assembly = server.outputRule?.lowercased() == "assembly"; var selected: [(String, Int, Entity)] = []; if assembly { for rule in server.serviceRules { guard let q = inputNames.first(where: { key in queues[key]!.contains(where: { $0.type.caseInsensitiveCompare(rule.entityType) == .orderedSame }) }), let position = queues[q]!.firstIndex(where: { $0.type.caseInsensitiveCompare(rule.entityType) == .orderedSame }) else { selected = []; break }; selected.append((q, position, queues[q]![position])) } } else if let q = inputNames.first(where: { !(queues[$0]?.isEmpty ?? true) }), let entity = queues[q]?.first { selected = [(q, 0, entity)] }; if selected.isEmpty { continue }; for (q, position, _) in selected.sorted(by: { $0.1 > $1.1 }) { queues[q]!.remove(at: position) }; let duration = selected.map { entity in sample(server.serviceRules.first(where: { $0.entityType.caseInsensitiveCompare(entity.2.type) == .orderedSame })?.distribution ?? server.serviceRules[0].distribution) }.max() ?? 0; busy.insert(i); busyTime[i, default: 0] += min(duration, max(0, horizon - time)); schedule(time + duration, .complete(i, selected.map { $0.2 })); changed = true } } }
        mutating func finish(_ index: Int, _ entities: [Entity], at time: Double) { busy.remove(index); serverCompleted[index, default: 0] += 1; let server = model.components[index]; if server.routes.isEmpty { completed += assemblyOutputCount(server, entities) } else { route(from: server, entities: [Entity(type: server.outputRule?.lowercased() == "assembly" ? "Assembly" : (entities.first?.type ?? server.name), entered: time)], at: time) }; dispatch(at: time) }
        func assemblyOutputCount(_ server: SimulationComponent, _ entities: [Entity]) -> Int { server.outputRule?.lowercased() == "assembly" ? 1 : entities.count }
        mutating func route(from component: SimulationComponent, entities: [Entity], at time: Double) { guard !component.routes.isEmpty else { completed += entities.count; return }; let draw = rng.unit(); var cumulative = 0.0; var chosen: SimulationRoute?; for route in component.routes { cumulative += route.probability; if draw <= cumulative { chosen = route; break } }; guard let route = chosen else { completed += entities.count; return }; for entity in entities { schedule(time + route.transferTime, .enter(route.target, entity)) } }
        mutating func sample(_ d: SimulationDistribution) -> Double { let p = d.parameters; switch d.kind { case .constant: return p.last ?? 1; case .exponential: let offset = p.count > 1 ? p[0] : 0, mean = p.last ?? 1; return offset - mean * log(max(1e-12, 1 - rng.unit())); case .normal: let u1 = max(1e-12, rng.unit()), u2 = rng.unit(); return max(0, (p.first ?? 0) + (p.last ?? 1) * sqrt(-2 * log(u1)) * cos(2 * .pi * u2)); case .uniform: return (p.first ?? 0) + rng.unit() * ((p.last ?? 1) - (p.first ?? 0)); case .triangular: let a = p.first ?? 0, m = p.count > 1 ? p[1] : a, b = p.last ?? m, u = rng.unit(), f = (m-a)/max(1e-12,b-a); return u < f ? a + sqrt(u*(b-a)*(m-a)) : b - sqrt((1-u)*(b-a)*(b-m)) } }
        mutating func schedule(_ time: Double, _ kind: EventKind) { events.append(Event(time: time, serial: serial, kind: kind)); serial += 1 }
        mutating func pop() -> Event? { guard !events.isEmpty else { return nil }; let i = events.indices.min { events[$0].time == events[$1].time ? events[$0].serial < events[$1].serial : events[$0].time < events[$1].time }!; return events.remove(at: i) }
        mutating func integrate(to time: Double) { let delta = time - lastTime; for (key, queue) in queues { queueArea[key, default: 0] += Double(queue.count) * delta }; lastTime = time }
    }
    private struct RNG { var state: UInt64; mutating func unit() -> Double { state = state &* 6364136223846793005 &+ 1442695040888963407; return Double(state >> 11) / Double(UInt64(1) << 53) } }
}

public protocol SimulationBackend: Sendable { var capabilities: SolverCapabilities { get }; func validationReport(for model: SimulationModel) -> ValidationReport; func solve(_ model: SimulationModel, options: SolverOptions) throws -> SimulationSolution; func runMetadata(for model: SimulationModel) -> SolverRunMetadata }
public extension SimulationBackend { func validationReport(for model: SimulationModel) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: SimulationValidator.diagnostics(for: model)) }; func solve(_ model: SimulationModel) throws -> SimulationSolution { try solve(model, options: SolverOptions()) }; func solutionDocument(for model: SimulationModel, solution: SimulationSolution) -> SimulationSolutionDocument { SimulationSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution) } }
public struct NativeEducationalSimulationBackend: SimulationBackend { public init() {} ; public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Deterministic-seed discrete-event simulation for preserved fixture-scale networks."]) }; public func solve(_ model: SimulationModel, options: SolverOptions = SolverOptions()) throws -> SimulationSolution { try DiscreteEventSimulationSolver.solve(model, horizon: options.timeLimitSeconds ?? 1_000, seed: options.randomSeed ?? 1) }; public func runMetadata(for _: SimulationModel) -> SolverRunMetadata { SolverRunMetadata(backendKind: .nativeEducational, algorithm: "seededDiscreteEventSimulation", exactness: .approximate, notes: ["Single seeded replication; stochastic confidence intervals are not reported."]) } }
public struct ValidateOnlySimulationBackend: SimulationBackend { public init() {}; public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }; public func solve(_ model: SimulationModel, options: SolverOptions = SolverOptions()) throws -> SimulationSolution { throw SimulationError.invalidModel("validateOnly backend does not run simulations") }; public func runMetadata(for _: SimulationModel) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact) } }
public enum SimulationBackends { public static func backend(for kind: SolverBackendKind) -> (any SimulationBackend)? { switch kind { case .nativeEducational: NativeEducationalSimulationBackend(); case .validateOnly: ValidateOnlySimulationBackend(); case .externalHighPerformance: nil } } }
public enum SimulationJSON { public static func encodeModel(_ value: SimulationModel) throws -> Data { try encoder.encode(value) }; public static func decodeUncheckedModel(from data: Data) throws -> SimulationModel { try JSONDecoder().decode(SimulationModel.self, from: data) }; public static func decodeModel(from data: Data) throws -> SimulationModel { let model = try decodeUncheckedModel(from: data); try SimulationValidator.validate(model); return model }; public static func encodeSolution(_ value: SimulationSolutionDocument) throws -> Data { try encoder.encode(value) }; public static func encodeValidation(_ value: SimulationValidationDocument) throws -> Data { try encoder.encode(value) }; private static var encoder: JSONEncoder { let value = JSONEncoder(); value.outputFormatting = [.prettyPrinted, .sortedKeys]; return value } }
