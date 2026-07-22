import Foundation

public enum QualityControlProblemKind: String, Codable, Sendable { case cChart, pChart, xbarRChart, pareto, normalProbabilityPlot }

public struct CChartModel: Codable, Equatable, Sendable {
    public let title: String; public let characteristic: String; public let counts: [Double]
    public init(title: String, characteristic: String, counts: [Double]) { self.title = title; self.characteristic = characteristic; self.counts = counts }
}
public struct PChartModel: Codable, Equatable, Sendable {
    public let title: String; public let characteristic: String; public let sampleSizes: [Int]; public let proportions: [Double]
    public init(title: String, characteristic: String, sampleSizes: [Int], proportions: [Double]) { self.title = title; self.characteristic = characteristic; self.sampleSizes = sampleSizes; self.proportions = proportions }
}
public struct XbarRChartModel: Codable, Equatable, Sendable {
    public let title: String; public let characteristic: String; public let subgroups: [[Double]]
    public init(title: String, characteristic: String, subgroups: [[Double]]) { self.title = title; self.characteristic = characteristic; self.subgroups = subgroups }
}
public struct ParetoModel: Codable, Equatable, Sendable {
    public let title: String; public let categoryNames: [String]; public let subgroupCounts: [[Double]]
    public init(title: String, categoryNames: [String], subgroupCounts: [[Double]]) { self.title = title; self.categoryNames = categoryNames; self.subgroupCounts = subgroupCounts }
}
public struct NormalProbabilityPlotModel: Codable, Equatable, Sendable {
    public let title: String; public let characteristic: String; public let values: [Double]
    public init(title: String, characteristic: String, values: [Double]) { self.title = title; self.characteristic = characteristic; self.values = values }
}

public enum QualityControlModelEnvelope: Codable, Equatable, Sendable {
    case cChart(CChartModel); case pChart(PChartModel); case xbarRChart(XbarRChartModel); case pareto(ParetoModel); case normalProbabilityPlot(NormalProbabilityPlotModel)
    private enum CodingKeys: String, CodingKey { case kind, model }
    public var kind: QualityControlProblemKind { switch self { case .cChart: .cChart; case .pChart: .pChart; case .xbarRChart: .xbarRChart; case .pareto: .pareto; case .normalProbabilityPlot: .normalProbabilityPlot } }
    public var title: String { switch self { case .cChart(let x): x.title; case .pChart(let x): x.title; case .xbarRChart(let x): x.title; case .pareto(let x): x.title; case .normalProbabilityPlot(let x): x.title } }
    public init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: CodingKeys.self); switch try c.decode(QualityControlProblemKind.self, forKey: .kind) { case .cChart: self = .cChart(try c.decode(CChartModel.self, forKey: .model)); case .pChart: self = .pChart(try c.decode(PChartModel.self, forKey: .model)); case .xbarRChart: self = .xbarRChart(try c.decode(XbarRChartModel.self, forKey: .model)); case .pareto: self = .pareto(try c.decode(ParetoModel.self, forKey: .model)); case .normalProbabilityPlot: self = .normalProbabilityPlot(try c.decode(NormalProbabilityPlotModel.self, forKey: .model)) } }
    public func encode(to encoder: Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(kind, forKey: .kind); switch self { case .cChart(let x): try c.encode(x, forKey: .model); case .pChart(let x): try c.encode(x, forKey: .model); case .xbarRChart(let x): try c.encode(x, forKey: .model); case .pareto(let x): try c.encode(x, forKey: .model); case .normalProbabilityPlot(let x): try c.encode(x, forKey: .model) } }
}

public struct ControlChartPoint: Codable, Equatable, Sendable { public let index: Int; public let value: Double; public let lowerControlLimit: Double; public let centerLine: Double; public let upperControlLimit: Double; public let isOutsideLimits: Bool }
public struct ControlChartSolution: Codable, Equatable, Sendable { public let points: [ControlChartPoint]; public let outsideLimitIndexes: [Int] }
public struct XbarRChartSolution: Codable, Equatable, Sendable { public let meanChart: ControlChartSolution; public let rangeChart: ControlChartSolution; public let grandMean: Double; public let averageRange: Double }
public struct ParetoCategory: Codable, Equatable, Sendable { public let name: String; public let count: Double; public let percentage: Double; public let cumulativePercentage: Double }
public struct ParetoSolution: Codable, Equatable, Sendable { public let totalCount: Double; public let categories: [ParetoCategory] }
public struct ProbabilityPlotPoint: Codable, Equatable, Sendable { public let rank: Int; public let value: Double; public let cumulativeProbability: Double; public let normalScore: Double; public let fittedValue: Double }
public struct NormalProbabilityPlotSolution: Codable, Equatable, Sendable { public let mean: Double; public let sampleStandardDeviation: Double; public let intercept: Double; public let slope: Double; public let correlation: Double; public let points: [ProbabilityPlotPoint] }

public enum QualityControlSolutionEnvelope: Codable, Equatable, Sendable {
    case cChart(ControlChartSolution); case pChart(ControlChartSolution); case xbarRChart(XbarRChartSolution); case pareto(ParetoSolution); case normalProbabilityPlot(NormalProbabilityPlotSolution)
    private enum CodingKeys: String, CodingKey { case kind, solution }
    public var kind: QualityControlProblemKind { switch self { case .cChart: .cChart; case .pChart: .pChart; case .xbarRChart: .xbarRChart; case .pareto: .pareto; case .normalProbabilityPlot: .normalProbabilityPlot } }
    public init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: CodingKeys.self); switch try c.decode(QualityControlProblemKind.self, forKey: .kind) { case .cChart: self = .cChart(try c.decode(ControlChartSolution.self, forKey: .solution)); case .pChart: self = .pChart(try c.decode(ControlChartSolution.self, forKey: .solution)); case .xbarRChart: self = .xbarRChart(try c.decode(XbarRChartSolution.self, forKey: .solution)); case .pareto: self = .pareto(try c.decode(ParetoSolution.self, forKey: .solution)); case .normalProbabilityPlot: self = .normalProbabilityPlot(try c.decode(NormalProbabilityPlotSolution.self, forKey: .solution)) } }
    public func encode(to encoder: Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(kind, forKey: .kind); switch self { case .cChart(let x): try c.encode(x, forKey: .solution); case .pChart(let x): try c.encode(x, forKey: .solution); case .xbarRChart(let x): try c.encode(x, forKey: .solution); case .pareto(let x): try c.encode(x, forKey: .solution); case .normalProbabilityPlot(let x): try c.encode(x, forKey: .solution) } }
}

public struct QualityControlSolutionDocument: Codable, Equatable, Sendable { public let backend: SolverRunMetadata; public let model: QualityControlModelEnvelope; public let solution: QualityControlSolutionEnvelope }
public struct QualityControlValidationDocument: Codable, Equatable, Sendable { public let kind: QualityControlProblemKind; public let backend: SolverBackendKind; public let isValid: Bool; public let diagnostics: [ValidationDiagnostic]; public init(kind: QualityControlProblemKind, backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) { self.kind = kind; self.backend = backend; self.isValid = !diagnostics.contains { $0.severity == .error }; self.diagnostics = diagnostics } }
public enum QualityControlError: Error, CustomStringConvertible { case unsupportedFormat; case invalidModel(String); public var description: String { switch self { case .unsupportedFormat: "Unsupported quality-control format"; case .invalidModel(let x): "Invalid quality-control model: \(x)" } } }

public enum WinQSBQualityControlParser {
    public static func parse(from data: Data) throws -> QualityControlModelEnvelope {
        guard let text = data.legacyLatin1String else { throw QualityControlError.unsupportedFormat }
        let rows = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").split(separator: "\n", omittingEmptySubsequences: true).map { $0.split(separator: "\t", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } }
        guard rows.count >= 5, rows[0].count >= 3, rows[0][0] == "QCC", rows[1].count >= 3, let characteristics = Int(rows[1][0]), let subgroups = Int(rows[1][1]), let subgroupSize = Int(rows[1][2]), rows[3].count >= 5 else { throw QualityControlError.unsupportedFormat }
        let isAttributeChart = rows[0][2] == "1"
        let requiredDataRows = isAttributeChart ? subgroups : subgroups * max(subgroupSize, 1)
        guard rows.count >= 4 + requiredDataRows else { throw QualityControlError.unsupportedFormat }
        let title = rows[0][1], header = rows[3]
        if isAttributeChart {
            if characteristics > 1 {
                let names = Array(header[5..<(4 + characteristics)])
                let values = try rows[4..<(4 + subgroups)].map { row in try row[5..<(4 + characteristics)].map(number) }
                return .pareto(ParetoModel(title: title, categoryNames: names, subgroupCounts: values))
            }
            let sizes = try rows[4..<(4 + subgroups)].map { Int(try number($0[3])) }
            let values = try rows[4..<(4 + subgroups)].map { try number($0[4]) }
            if header[4].contains("%") { return .pChart(PChartModel(title: title, characteristic: header[4], sampleSizes: sizes, proportions: values)) }
            return .cChart(CChartModel(title: title, characteristic: header[4], counts: values))
        }
        let dataRows = Array(rows[4..<(4 + subgroups * subgroupSize)])
        let values = try dataRows.map { try number($0[4]) }
        if subgroupSize == 1 { return .normalProbabilityPlot(NormalProbabilityPlotModel(title: title, characteristic: header[4], values: values)) }
        var grouped = Array(repeating: [Double](), count: subgroups)
        for row in dataRows { let group = Int(try number(row[3])); guard group >= 1, group <= subgroups else { throw QualityControlError.invalidModel("Subgroup index is outside declared range") }; grouped[group - 1].append(try number(row[4])) }
        return .xbarRChart(XbarRChartModel(title: title, characteristic: header[4], subgroups: grouped))
    }
    private static func number(_ raw: String) throws -> Double { guard let x = Double(raw), x.isFinite else { throw QualityControlError.invalidModel("Invalid numeric value \(raw)") }; return x }
}

public enum QualityControlValidator {
    public static func diagnostics(for model: QualityControlModelEnvelope) -> [ValidationDiagnostic] {
        var r: [ValidationDiagnostic] = []
        switch model {
        case .cChart(let x): if x.counts.isEmpty || x.counts.contains(where: { !$0.isFinite || $0 < 0 }) { r.append(error("cChart.counts", "Counts must be finite, nonnegative, and nonempty.", "model.counts")) }
        case .pChart(let x): if x.proportions.isEmpty || x.proportions.count != x.sampleSizes.count { r.append(error("pChart.dimension", "Proportions and sample sizes must have matching nonempty dimensions.", "model")) }; if x.proportions.contains(where: { !$0.isFinite || $0 < 0 || $0 > 1 }) || x.sampleSizes.contains(where: { $0 <= 0 }) { r.append(error("pChart.values", "Proportions must be probabilities and sample sizes positive.", "model")) }
        case .xbarRChart(let x): if x.subgroups.isEmpty || x.subgroups.contains(where: { $0.count < 2 || $0.count > 10 }) { r.append(error("xbarR.subgroups", "Xbar-R requires nonempty subgroups of common size 2 through 10.", "model.subgroups")) }; if Set(x.subgroups.map(\.count)).count > 1 { r.append(error("xbarR.size", "All subgroups must have the same size.", "model.subgroups")) }; if x.subgroups.flatMap({ $0 }).contains(where: { !$0.isFinite }) { r.append(error("xbarR.finite", "Measurements must be finite.", "model.subgroups")) }
        case .pareto(let x): if x.categoryNames.isEmpty || x.subgroupCounts.contains(where: { $0.count != x.categoryNames.count }) { r.append(error("pareto.dimension", "Pareto category dimensions must match.", "model")) }; if x.subgroupCounts.flatMap({ $0 }).contains(where: { !$0.isFinite || $0 < 0 }) { r.append(error("pareto.values", "Pareto counts must be finite and nonnegative.", "model.subgroupCounts")) }
        case .normalProbabilityPlot(let x): if x.values.count < 3 || x.values.contains(where: { !$0.isFinite }) { r.append(error("probabilityPlot.values", "Probability plot requires at least three finite values.", "model.values")) }
        }
        guard !r.contains(where: { $0.severity == .error }) else { return r }; return [ValidationDiagnostic(severity: .info, code: "qualityControl.\(model.kind.rawValue).valid", message: "Quality-control model is valid")]
    }
    public static func validate(_ model: QualityControlModelEnvelope) throws { if let x = diagnostics(for: model).first(where: { $0.severity == .error }) { throw QualityControlError.invalidModel(x.message) } }
    private static func error(_ code: String, _ message: String, _ path: String) -> ValidationDiagnostic { ValidationDiagnostic(severity: .error, code: "qualityControl.\(code)", message: message, path: path) }
}

public enum QualityControlSolver {
    public static func solve(_ model: QualityControlModelEnvelope) throws -> QualityControlSolutionEnvelope {
        try QualityControlValidator.validate(model)
        switch model {
        case .cChart(let x):
            let center = mean(x.counts), sigma = sqrt(center); return .cChart(chart(values: x.counts, centers: Array(repeating: center, count: x.counts.count), lowers: Array(repeating: max(0, center - 3 * sigma), count: x.counts.count), uppers: Array(repeating: center + 3 * sigma, count: x.counts.count)))
        case .pChart(let x):
            let defects = zip(x.proportions, x.sampleSizes).reduce(0.0) { $0 + $1.0 * Double($1.1) }, total = x.sampleSizes.reduce(0, +); let center = defects / Double(total)
            let sigmas = x.sampleSizes.map { sqrt(center * (1 - center) / Double($0)) }
            return .pChart(chart(values: x.proportions, centers: Array(repeating: center, count: x.proportions.count), lowers: sigmas.map { max(0, center - 3 * $0) }, uppers: sigmas.map { min(1, center + 3 * $0) }))
        case .xbarRChart(let x):
            let means = x.subgroups.map(mean), ranges = x.subgroups.map { ($0.max() ?? 0) - ($0.min() ?? 0) }, grand = mean(means), averageRange = mean(ranges), constants = constantsForSubgroupSize(x.subgroups[0].count)
            let meanSolution = chart(values: means, centers: Array(repeating: grand, count: means.count), lowers: Array(repeating: grand - constants.a2 * averageRange, count: means.count), uppers: Array(repeating: grand + constants.a2 * averageRange, count: means.count))
            let rangeSolution = chart(values: ranges, centers: Array(repeating: averageRange, count: ranges.count), lowers: Array(repeating: constants.d3 * averageRange, count: ranges.count), uppers: Array(repeating: constants.d4 * averageRange, count: ranges.count))
            return .xbarRChart(XbarRChartSolution(meanChart: meanSolution, rangeChart: rangeSolution, grandMean: grand, averageRange: averageRange))
        case .pareto(let x):
            let totals = x.categoryNames.indices.map { i in x.subgroupCounts.reduce(0) { $0 + $1[i] } }, overall = totals.reduce(0, +), sorted = zip(x.categoryNames, totals).sorted { $0.1 > $1.1 }; var cumulative = 0.0
            let categories = sorted.map { name, count -> ParetoCategory in cumulative += count; return ParetoCategory(name: name, count: count, percentage: overall == 0 ? 0 : count / overall, cumulativePercentage: overall == 0 ? 0 : cumulative / overall) }
            return .pareto(ParetoSolution(totalCount: overall, categories: categories))
        case .normalProbabilityPlot(let x): return .normalProbabilityPlot(probabilityPlot(x.values))
        }
    }
    private static func chart(values: [Double], centers: [Double], lowers: [Double], uppers: [Double]) -> ControlChartSolution { let points = values.indices.map { i in ControlChartPoint(index: i + 1, value: values[i], lowerControlLimit: lowers[i], centerLine: centers[i], upperControlLimit: uppers[i], isOutsideLimits: values[i] < lowers[i] || values[i] > uppers[i]) }; return ControlChartSolution(points: points, outsideLimitIndexes: points.filter(\.isOutsideLimits).map(\.index)) }
    private static func mean(_ x: [Double]) -> Double { x.reduce(0, +) / Double(x.count) }
    private static func constantsForSubgroupSize(_ n: Int) -> (a2: Double, d3: Double, d4: Double) { let values: [Int: (Double, Double, Double)] = [2:(1.880,0,3.267),3:(1.023,0,2.574),4:(0.729,0,2.282),5:(0.577,0,2.114),6:(0.483,0,2.004),7:(0.419,0.076,1.924),8:(0.373,0.136,1.864),9:(0.337,0.184,1.816),10:(0.308,0.223,1.777)]; return values[n]! }
    private static func probabilityPlot(_ values: [Double]) -> NormalProbabilityPlotSolution { let sorted = values.sorted(), n = Double(sorted.count), scores = sorted.indices.map { inverseNormal((Double($0 + 1) - 0.375) / (n + 0.25)) }, scoreMean = mean(scores), valueMean = mean(sorted), covariance = zip(scores, sorted).reduce(0) { $0 + ($1.0 - scoreMean) * ($1.1 - valueMean) }, scoreSS = scores.reduce(0) { $0 + pow($1 - scoreMean, 2) }, valueSS = sorted.reduce(0) { $0 + pow($1 - valueMean, 2) }, slope = covariance / scoreSS, intercept = valueMean - slope * scoreMean, correlation = covariance / sqrt(scoreSS * valueSS), points = sorted.indices.map { ProbabilityPlotPoint(rank: $0 + 1, value: sorted[$0], cumulativeProbability: (Double($0 + 1) - 0.375) / (n + 0.25), normalScore: scores[$0], fittedValue: intercept + slope * scores[$0]) }; return NormalProbabilityPlotSolution(mean: valueMean, sampleStandardDeviation: sqrt(valueSS / Double(sorted.count - 1)), intercept: intercept, slope: slope, correlation: correlation, points: points) }
    private static func inverseNormal(_ p: Double) -> Double { let a = [-39.6968302866538,220.946098424521,-275.928510446969,138.357751867269,-30.6647980661472,2.50662827745924], b = [-54.4760987982241,161.585836858041,-155.698979859887,66.8013118877197,-13.2806815528857], c = [-0.00778489400243029,-0.322396458041136,-2.40075827716184,-2.54973253934373,4.37466414146497,2.93816398269878], d = [0.00778469570904146,0.32246712907004,2.445134137143,3.75440866190742]; if p < 0.02425 { let q = sqrt(-2 * log(p)); return (((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5])/((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1) }; if p > 0.97575 { return -inverseNormal(1-p) }; let q=p-0.5,r=q*q; return (((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*q/(((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1) }
}

public protocol QualityControlBackend: Sendable { var capabilities: SolverCapabilities { get }; func validationReport(for model: QualityControlModelEnvelope) -> ValidationReport; func solve(_ model: QualityControlModelEnvelope, options: SolverOptions) throws -> QualityControlSolutionEnvelope; func runMetadata(for model: QualityControlModelEnvelope) -> SolverRunMetadata }
public extension QualityControlBackend { func validationReport(for model: QualityControlModelEnvelope) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: QualityControlValidator.diagnostics(for: model)) }; func solve(_ model: QualityControlModelEnvelope) throws -> QualityControlSolutionEnvelope { try solve(model, options: SolverOptions()) }; func solutionDocument(for model: QualityControlModelEnvelope, solution: QualityControlSolutionEnvelope) -> QualityControlSolutionDocument { QualityControlSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution) } }
public struct NativeEducationalQualityControlBackend: QualityControlBackend { public init() {}; public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Transparent classical quality-control statistics."]) }; public func solve(_ model: QualityControlModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> QualityControlSolutionEnvelope { try QualityControlSolver.solve(model) }; public func runMetadata(for model: QualityControlModelEnvelope) -> SolverRunMetadata { let algorithm: String = switch model.kind { case .cChart:"threeSigmaCChart"; case .pChart:"threeSigmaPChart"; case .xbarRChart:"xbarRControlChart"; case .pareto:"descendingParetoAggregation"; case .normalProbabilityPlot:"normalScoreLeastSquares" }; return SolverRunMetadata(backendKind: .nativeEducational, algorithm: algorithm, exactness: model.kind == .normalProbabilityPlot ? .approximate : .exact, notes: ["Configured Western Electric rules and cause/action metadata are preserved only in legacy payloads and are not evaluated yet."]) } }
public struct ValidateOnlyQualityControlBackend: QualityControlBackend { public init() {}; public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }; public func solve(_ model: QualityControlModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> QualityControlSolutionEnvelope { throw QualityControlError.invalidModel("validateOnly backend does not evaluate quality-control models") }; public func runMetadata(for _: QualityControlModelEnvelope) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact) } }
public enum QualityControlBackends { public static func backend(for kind: SolverBackendKind) -> (any QualityControlBackend)? { switch kind { case .nativeEducational: NativeEducationalQualityControlBackend(); case .validateOnly: ValidateOnlyQualityControlBackend(); case .externalHighPerformance: nil } } }
public enum QualityControlJSON { public static func encodeModel(_ x: QualityControlModelEnvelope) throws -> Data { try encoder.encode(x) }; public static func decodeModel(from x: Data) throws -> QualityControlModelEnvelope { try JSONDecoder().decode(QualityControlModelEnvelope.self, from: x) }; public static func encodeSolution(_ x: QualityControlSolutionDocument) throws -> Data { try encoder.encode(x) }; public static func decodeSolution(from x: Data) throws -> QualityControlSolutionDocument { try JSONDecoder().decode(QualityControlSolutionDocument.self, from: x) }; public static func encodeValidation(_ x: QualityControlValidationDocument) throws -> Data { try encoder.encode(x) }; private static var encoder: JSONEncoder { let x=JSONEncoder();x.outputFormatting=[.prettyPrinted,.sortedKeys];return x } }
