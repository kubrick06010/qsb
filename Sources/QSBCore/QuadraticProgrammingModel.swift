import Foundation

public struct QuadraticProgram: Codable, Equatable, Sendable {
    public let title: String
    public let sense: ObjectiveSense
    public let variableNames: [String]
    public let linearCoefficients: [Double]
    public let quadraticMatrix: [[Double]]
    public let constraints: [LinearConstraint]
    public let lowerBounds: [Double?]
    public let upperBounds: [Double?]
    public let variableTypes: [VariableType]

    public init(title: String, sense: ObjectiveSense, variableNames: [String], linearCoefficients: [Double], quadraticMatrix: [[Double]], constraints: [LinearConstraint], lowerBounds: [Double?], upperBounds: [Double?], variableTypes: [VariableType]) {
        self.title = title; self.sense = sense; self.variableNames = variableNames
        self.linearCoefficients = linearCoefficients; self.quadraticMatrix = quadraticMatrix
        self.constraints = constraints; self.lowerBounds = lowerBounds; self.upperBounds = upperBounds
        self.variableTypes = variableTypes
    }
}

public struct QuadraticProgramSolution: Codable, Equatable, Sendable {
    public let objectiveValue: Double
    public let variableValues: [String: Double]
    public let activeConstraints: [String]
}

public struct QuadraticProgramSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let model: QuadraticProgram
    public let solution: QuadraticProgramSolution
}

public struct QuadraticProgramValidationDocument: Codable, Equatable, Sendable {
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]
    public init(backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.backend = backend; self.isValid = !diagnostics.contains { $0.severity == .error }; self.diagnostics = diagnostics
    }
}

public enum QuadraticProgrammingError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidModel(String)
    case infeasible

    public var description: String {
        switch self {
        case .unsupportedFormat: "Unsupported quadratic-programming format"
        case .invalidModel(let message): "Invalid quadratic program: \(message)"
        case .infeasible: "Quadratic program is infeasible"
        }
    }
}

public enum WinQSBQuadraticProgrammingParser {
    public static func parse(from data: Data) throws -> QuadraticProgram {
        guard let text = data.legacyLatin1String else { throw QuadraticProgrammingError.unsupportedFormat }
        let rows = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").split(separator: "\n", omittingEmptySubsequences: true).map { $0.split(separator: "\t", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } }
        guard let metadata = rows.first, metadata.count >= 5, metadata[0] == "QP", let variableCount = Int(metadata[3].trimmingCharacters(in: .whitespaces)), let constraintCount = Int(metadata[4].trimmingCharacters(in: .whitespaces)) else { throw QuadraticProgrammingError.unsupportedFormat }
        let program: QuadraticProgram
        switch metadata[1] {
        case "MatrixFormat": program = try parseMatrix(rows, title: metadata[2], variableCount: variableCount, constraintCount: constraintCount)
        case "NormalModel": program = try parseNormal(rows, title: metadata[2], variableCount: variableCount, constraintCount: constraintCount)
        default: throw QuadraticProgrammingError.unsupportedFormat
        }
        try QuadraticProgramValidator.validate(program)
        return program
    }

    private static func parseMatrix(_ rows: [[String]], title: String, variableCount n: Int, constraintCount m: Int) throws -> QuadraticProgram {
        guard rows.count >= 5 + n + m, rows[1].count >= n + 3 else { throw QuadraticProgrammingError.unsupportedFormat }
        let names = Array(rows[1][1...n])
        let objective = rows[2]
        let sense = try objectiveSense(objective[0])
        let linear = try (0..<n).map { try number(objective[$0 + 1]) }
        var matrix = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for rowIndex in 0..<n {
            let row = rows[3 + rowIndex]
            for column in 0..<n where column + 1 < row.count && !row[column + 1].isEmpty {
                let coefficient = try number(row[column + 1])
                if rowIndex == column { matrix[rowIndex][column] += coefficient }
                else { matrix[rowIndex][column] += coefficient / 2; matrix[column][rowIndex] += coefficient / 2 }
            }
        }
        let constraintStart = 3 + n
        let constraints = try (0..<m).map { index -> LinearConstraint in
            let row = rows[constraintStart + index]
            guard row.count >= n + 3 else { throw QuadraticProgrammingError.unsupportedFormat }
            return LinearConstraint(name: row[0], coefficients: try (0..<n).map { try number(row[$0 + 1]) }, relation: try relation(row[n + 1]), rhs: try number(row[n + 2]))
        }
        let lowerRow = rows[constraintStart + m], upperRow = rows[constraintStart + m + 1], typeRow = rows[constraintStart + m + 2]
        let lowers = try (0..<n).map { try bound(lowerRow[$0 + 1]) ?? 0 }
        let uppers = try (0..<n).map { try bound(upperRow[$0 + 1]) }
        let types = try (0..<n).map { try variableType(typeRow[$0 + 1]) }
        return QuadraticProgram(title: title, sense: sense, variableNames: names, linearCoefficients: linear, quadraticMatrix: matrix, constraints: constraints, lowerBounds: lowers.map(Optional.some), upperBounds: uppers, variableTypes: types)
    }

    private static func parseNormal(_ rows: [[String]], title: String, variableCount n: Int, constraintCount m: Int) throws -> QuadraticProgram {
        guard rows.count >= 7 + n, rows[2].count >= 2 else { throw QuadraticProgrammingError.unsupportedFormat }
        let boundRows = Array(rows.suffix(n))
        let names = boundRows.map { $0[0] }
        let sense = try objectiveSense(rows[2][0])
        let polynomial = try parsePolynomial(rows[2][1], names: names)
        let constraints = try (0..<m).map { index -> LinearConstraint in
            let row = rows[3 + index]
            guard row.count >= 2 else { throw QuadraticProgrammingError.unsupportedFormat }
            return try parseConstraint(name: row[0], expression: row[1], names: names)
        }
        let integerNames = Set(list(after: "Integer:", in: rows)), binaryNames = Set(list(after: "Binary:", in: rows)), unrestricted = Set(list(after: "Unrestricted:", in: rows))
        var lowers: [Double?] = [], uppers: [Double?] = [], types: [VariableType] = []
        for (index, name) in names.enumerated() {
            let row = boundRows[index]
            let text = row.dropFirst().joined(separator: " ")
            lowers.append(unrestricted.contains(name) ? nil : try parsedBound(text, marker: ">=") ?? 0)
            uppers.append(try parsedBound(text, marker: "<="))
            types.append(binaryNames.contains(name) ? .binary : integerNames.contains(name) ? .integer : .continuous)
        }
        return QuadraticProgram(title: title, sense: sense, variableNames: names, linearCoefficients: polynomial.linear, quadraticMatrix: polynomial.matrix, constraints: constraints, lowerBounds: lowers, upperBounds: uppers, variableTypes: types)
    }

    private static func parsePolynomial(_ expression: String, names: [String]) throws -> (linear: [Double], matrix: [[Double]]) {
        var linear = Array(repeating: 0.0, count: names.count), matrix = Array(repeating: Array(repeating: 0.0, count: names.count), count: names.count)
        for term in signedTerms(expression) {
            let factors = term.body.split(separator: "*").map(String.init)
            guard let first = factors.first else { continue }
            let (coefficient, firstName) = try coefficientAndName(first, sign: term.sign, names: names)
            guard let firstIndex = names.firstIndex(of: firstName) else { throw QuadraticProgrammingError.invalidModel("Unknown variable \(firstName)") }
            if factors.count == 1 { linear[firstIndex] += coefficient }
            else if factors.count == 2, let secondIndex = names.firstIndex(of: factors[1]) {
                if firstIndex == secondIndex { matrix[firstIndex][secondIndex] += coefficient }
                else { matrix[firstIndex][secondIndex] += coefficient / 2; matrix[secondIndex][firstIndex] += coefficient / 2 }
            } else { throw QuadraticProgrammingError.invalidModel("Objective term '\(term.body)' is not quadratic") }
        }
        return (linear, matrix)
    }

    private static func parseConstraint(name: String, expression: String, names: [String]) throws -> LinearConstraint {
        let marker: String
        if expression.contains("<=") { marker = "<=" } else if expression.contains(">=") { marker = ">=" } else if expression.contains("=") { marker = "=" } else { throw QuadraticProgrammingError.unsupportedFormat }
        let parts = expression.components(separatedBy: marker)
        guard parts.count == 2, let rhs = Double(parts[1]) else { throw QuadraticProgrammingError.unsupportedFormat }
        var coefficients = Array(repeating: 0.0, count: names.count)
        for term in signedTerms(parts[0]) {
            let (coefficient, variable) = try coefficientAndName(term.body, sign: term.sign, names: names)
            guard let index = names.firstIndex(of: variable) else { throw QuadraticProgrammingError.invalidModel("Unknown variable \(variable)") }
            coefficients[index] += coefficient
        }
        return LinearConstraint(name: name, coefficients: coefficients, relation: try relation(marker), rhs: rhs)
    }

    private static func signedTerms(_ raw: String) -> [(sign: Double, body: String)] {
        let text = raw.replacingOccurrences(of: " ", with: "")
        var result: [(Double, String)] = [], start = text.startIndex, sign = 1.0
        if start < text.endIndex, text[start] == "+" || text[start] == "-" { sign = text[start] == "-" ? -1 : 1; start = text.index(after: start) }
        var index = start
        while index < text.endIndex {
            if text[index] == "+" || text[index] == "-" {
                result.append((sign, String(text[start..<index])))
                sign = text[index] == "-" ? -1 : 1; start = text.index(after: index)
            }
            index = text.index(after: index)
        }
        if start < text.endIndex { result.append((sign, String(text[start...]))) }
        return result
    }

    private static func coefficientAndName(_ raw: String, sign: Double, names: [String]) throws -> (Double, String) {
        guard let name = names.sorted(by: { $0.count > $1.count }).first(where: { raw.hasSuffix($0) }) else { throw QuadraticProgrammingError.invalidModel("Cannot parse term '\(raw)'") }
        let prefix = String(raw.dropLast(name.count))
        let coefficient = prefix.isEmpty ? 1 : Double(prefix)
        guard let coefficient else { throw QuadraticProgrammingError.invalidModel("Cannot parse coefficient '\(prefix)'") }
        return (sign * coefficient, name)
    }

    private static func list(after marker: String, in rows: [[String]]) -> [String] { rows.first(where: { $0.first == marker })?.dropFirst().flatMap { $0.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init) } ?? [] }
    private static func parsedBound(_ text: String, marker: String) throws -> Double? { guard let range = text.range(of: marker) else { return nil }; let tail = text[range.upperBound...].split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""; return try bound(tail) }
    private static func objectiveSense(_ raw: String) throws -> ObjectiveSense { if raw.caseInsensitiveCompare("Maximize") == .orderedSame { return .maximize }; if raw.caseInsensitiveCompare("Minimize") == .orderedSame { return .minimize }; throw QuadraticProgrammingError.unsupportedFormat }
    private static func relation(_ raw: String) throws -> ConstraintRelation { guard let value = ConstraintRelation(rawValue: raw) else { throw QuadraticProgrammingError.unsupportedFormat }; return value }
    private static func variableType(_ raw: String) throws -> VariableType { switch raw.lowercased() { case "continuous": .continuous; case "integer": .integer; case "binary": .binary; default: throw QuadraticProgrammingError.unsupportedFormat } }
    private static func number(_ raw: String) throws -> Double { guard let value = Double(raw), value.isFinite else { throw QuadraticProgrammingError.invalidModel("Invalid number '\(raw)'") }; return value }
    private static func bound(_ raw: String) throws -> Double? { let text = raw.trimmingCharacters(in: .whitespaces); if text.isEmpty || text.lowercased() == "m" { return nil }; return try number(text) }
}

public enum QuadraticProgramValidator {
    public static func diagnostics(for model: QuadraticProgram) -> [ValidationDiagnostic] {
        let n = model.variableNames.count
        var result: [ValidationDiagnostic] = []
        if n == 0 || Set(model.variableNames).count != n || model.linearCoefficients.count != n || model.quadraticMatrix.count != n || model.quadraticMatrix.contains(where: { $0.count != n }) || model.lowerBounds.count != n || model.upperBounds.count != n || model.variableTypes.count != n {
            result.append(error("dimension", "Variable, objective, matrix, bound, and type dimensions must agree.", "model"))
        }
        if model.linearCoefficients.contains(where: { !$0.isFinite }) || model.quadraticMatrix.flatMap({ $0 }).contains(where: { !$0.isFinite }) || model.constraints.contains(where: { $0.coefficients.count != n || !$0.rhs.isFinite || $0.coefficients.contains(where: { !$0.isFinite }) }) {
            result.append(error("finite", "All coefficients and right-hand sides must be finite.", "model"))
        }
        if model.quadraticMatrix.indices.contains(where: { i in model.quadraticMatrix.indices.contains(where: { j in abs(model.quadraticMatrix[i][j] - model.quadraticMatrix[j][i]) > 1e-9 }) }) {
            result.append(error("symmetry", "Quadratic matrix must be symmetric.", "model.quadraticMatrix"))
        }
        for index in 0..<min(n, model.lowerBounds.count) {
            if let lower = model.lowerBounds[index], let upper = model.upperBounds[index], lower > upper { result.append(error("bounds", "Lower bound exceeds upper bound.", "model.lowerBounds[\(index)]")) }
        }
        if n > 0 && model.quadraticMatrix.count == n && model.quadraticMatrix.allSatisfy({ $0.count == n }) {
            let signed = model.sense == .maximize ? model.quadraticMatrix.map { $0.map { -$0 } } : model.quadraticMatrix
            if !isPositiveDefinite(signed) { result.append(error("curvature", "Native solving requires a strictly concave maximization or strictly convex minimization objective.", "model.quadraticMatrix")) }
        }
        let hasIntegers = model.variableTypes.contains { $0 != .continuous }
        if hasIntegers && model.quadraticMatrix.indices.contains(where: { i in model.quadraticMatrix.indices.contains(where: { j in i != j && abs(model.quadraticMatrix[i][j]) > 1e-12 }) }) {
            result.append(error("integerCrossTerms", "Native integer QP supports diagonal quadratic objectives only.", "model.quadraticMatrix"))
        }
        if result.isEmpty { result.append(ValidationDiagnostic(severity: .info, code: "qp.valid", message: "Quadratic program is valid")) }
        return result
    }

    public static func validate(_ model: QuadraticProgram) throws { if let item = diagnostics(for: model).first(where: { $0.severity == .error }) { throw QuadraticProgrammingError.invalidModel(item.message) } }
    private static func error(_ code: String, _ message: String, _ path: String) -> ValidationDiagnostic { ValidationDiagnostic(severity: .error, code: "qp.\(code)", message: message, path: path) }
    private static func isPositiveDefinite(_ matrix: [[Double]]) -> Bool {
        let n = matrix.count; var lower = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n { for j in 0...i { var sum = matrix[i][j]; for k in 0..<j { sum -= lower[i][k] * lower[j][k] }; if i == j { if sum <= 1e-10 { return false }; lower[i][j] = sqrt(sum) } else { lower[i][j] = sum / lower[j][j] } } }
        return true
    }
}

public enum QuadraticProgrammingSolver {
    public static func solve(_ model: QuadraticProgram) throws -> QuadraticProgramSolution {
        try QuadraticProgramValidator.validate(model)
        return model.variableTypes.allSatisfy { $0 == .continuous } ? try solveContinuous(model) : try solveInteger(model)
    }

    private struct AffineBoundary { let name: String; let coefficients: [Double]; let rhs: Double }

    private static func solveContinuous(_ model: QuadraticProgram) throws -> QuadraticProgramSolution {
        let n = model.variableNames.count
        var equalities: [AffineBoundary] = [], inequalities: [AffineBoundary] = []
        for constraint in model.constraints { switch constraint.relation { case .equal: equalities.append(AffineBoundary(name: constraint.name, coefficients: constraint.coefficients, rhs: constraint.rhs)); case .lessThanOrEqual: inequalities.append(AffineBoundary(name: constraint.name, coefficients: constraint.coefficients, rhs: constraint.rhs)); case .greaterThanOrEqual: inequalities.append(AffineBoundary(name: constraint.name, coefficients: constraint.coefficients.map { -$0 }, rhs: -constraint.rhs)) } }
        for i in 0..<n { if let lower = model.lowerBounds[i] { var row=Array(repeating:0.0,count:n);row[i] = -1;inequalities.append(AffineBoundary(name:"\(model.variableNames[i]) lower",coefficients:row,rhs:-lower)) }; if let upper=model.upperBounds[i] { var row=Array(repeating:0.0,count:n);row[i]=1;inequalities.append(AffineBoundary(name:"\(model.variableNames[i]) upper",coefficients:row,rhs:upper)) } }
        guard inequalities.count <= 20 else { throw QuadraticProgrammingError.invalidModel("Too many active-set candidates for native solver") }
        var best: (value: Double, point: [Double], active: [String])?
        for mask in 0..<(1 << inequalities.count) {
            let active = equalities + inequalities.indices.filter { mask & (1 << $0) != 0 }.map { inequalities[$0] }
            guard active.count <= n, let point = stationaryPoint(model, active: active), feasible(point, model: model) else { continue }
            let value = objective(point, model)
            if best == nil || better(value, than: best!.value, sense: model.sense) { best = (value, point, active.map(\.name)) }
        }
        guard let best else { throw QuadraticProgrammingError.infeasible }
        return QuadraticProgramSolution(objectiveValue: best.value, variableValues: Dictionary(uniqueKeysWithValues: zip(model.variableNames, best.point)), activeConstraints: best.active)
    }

    private static func stationaryPoint(_ model: QuadraticProgram, active: [AffineBoundary]) -> [Double]? {
        let n=model.variableNames.count,m=active.count,size=n+m; var a=Array(repeating:Array(repeating:0.0,count:size),count:size), b=Array(repeating:0.0,count:size)
        for i in 0..<n { for j in 0..<n { a[i][j]=2*model.quadraticMatrix[i][j] }; b[i] = -model.linearCoefficients[i] }
        for k in 0..<m { for i in 0..<n { a[i][n+k]=active[k].coefficients[i];a[n+k][i]=active[k].coefficients[i] };b[n+k]=active[k].rhs }
        return solveLinearSystem(a,b).map { Array($0.prefix(n)) }
    }

    private static func solveInteger(_ model: QuadraticProgram) throws -> QuadraticProgramSolution {
        guard model.sense == .maximize, model.variableNames.count <= 4, model.lowerBounds.allSatisfy({ ($0 ?? 0) >= 0 }) else { throw QuadraticProgrammingError.invalidModel("Native integer QP is limited to nonnegative, diagonal, concave maximization with at most four variables") }
        let n=model.variableNames.count
        var seed: (Double,[Double])?
        for cube in [8,16,32,64] { enumerate(bounds:Array(repeating:cube,count:n),model:model) { point in let value=objective(point,model);if seed == nil || value>seed!.0 { seed=(value,point) } };if seed != nil { break } }
        guard let incumbent=seed else { throw QuadraticProgrammingError.infeasible }
        let maxima = (0..<n).map { i -> Double in let q=model.quadraticMatrix[i][i],c=model.linearCoefficients[i];let x=max(0,-c/(2*q));return q*x*x+c*x }
        var bounds:[Int]=[]
        for i in 0..<n { let q=model.quadraticMatrix[i][i],c=model.linearCoefficients[i],threshold=incumbent.0-(maxima.reduce(0,+)-maxima[i]),disc=c*c+4*q*threshold;guard disc>=0 else { throw QuadraticProgrammingError.infeasible };var upper=Int(ceil((-c-sqrt(disc))/(2*q)));if let explicit=model.upperBounds[i] { upper=min(upper,Int(floor(explicit))) };if model.variableTypes[i] == .binary { upper=min(upper,1) };bounds.append(max(0,upper)) }
        var best=incumbent
        enumerate(bounds:bounds,model:model) { point in let value=objective(point,model);if value>best.0 { best=(value,point) } }
        let active=model.constraints.filter { abs(dot($0.coefficients,best.1)-$0.rhs)<1e-7 }.map(\.name)
        return QuadraticProgramSolution(objectiveValue: best.0,variableValues:Dictionary(uniqueKeysWithValues:zip(model.variableNames,best.1)),activeConstraints:active)
    }

    private static func enumerate(bounds:[Int],model:QuadraticProgram,visit:([Double])->Void) { var point=Array(repeating:0.0,count:bounds.count);func walk(_ i:Int){if i==bounds.count { if feasible(point,model:model){visit(point)};return };let lower=Int(ceil(model.lowerBounds[i] ?? 0));if lower>bounds[i]{return};for value in lower...bounds[i]{point[i]=Double(value);walk(i+1)}};walk(0) }
    private static func feasible(_ x:[Double],model:QuadraticProgram)->Bool { for i in x.indices { if let l=model.lowerBounds[i],x[i]<l-1e-7{return false};if let u=model.upperBounds[i],x[i]>u+1e-7{return false} };for c in model.constraints { let v=dot(c.coefficients,x);switch c.relation {case .lessThanOrEqual:if v>c.rhs+1e-7{return false};case .greaterThanOrEqual:if v<c.rhs-1e-7{return false};case .equal:if abs(v-c.rhs)>1e-7{return false}}};return true }
    private static func objective(_ x:[Double],_ model:QuadraticProgram)->Double { var value=dot(model.linearCoefficients,x);for i in x.indices {for j in x.indices {value += x[i]*model.quadraticMatrix[i][j]*x[j]}};return value }
    private static func better(_ x:Double,than y:Double,sense:ObjectiveSense)->Bool { sense == .maximize ? x>y+1e-9 : x<y-1e-9 }
    private static func dot(_ a:[Double],_ b:[Double])->Double { zip(a,b).reduce(0){$0+$1.0*$1.1} }
    private static func solveLinearSystem(_ input:[[Double]],_ rhs:[Double])->[Double]? { let n=rhs.count;var a=input,b=rhs;for p in 0..<n { var best=p;for r in p..<n where abs(a[r][p])>abs(a[best][p]){best=r};if abs(a[best][p])<1e-10{return nil};a.swapAt(p,best);b.swapAt(p,best);let pivot=a[p][p];for c in p..<n{a[p][c]/=pivot};b[p]/=pivot;for r in 0..<n where r != p {let f=a[r][p];if abs(f)<1e-14{continue};for c in p..<n{a[r][c]-=f*a[p][c]};b[r]-=f*b[p]}};return b }
}

public protocol QuadraticProgrammingBackend: Sendable { var capabilities:SolverCapabilities{get};func validationReport(for model:QuadraticProgram)->ValidationReport;func solve(_ model:QuadraticProgram,options:SolverOptions)throws->QuadraticProgramSolution;func runMetadata(for model:QuadraticProgram)->SolverRunMetadata }
public extension QuadraticProgrammingBackend { func validationReport(for model:QuadraticProgram)->ValidationReport{ValidationReport(backend:capabilities.backendKind,diagnostics:QuadraticProgramValidator.diagnostics(for:model))};func solve(_ model:QuadraticProgram)throws->QuadraticProgramSolution{try solve(model,options:SolverOptions())};func solutionDocument(for model:QuadraticProgram,solution:QuadraticProgramSolution)->QuadraticProgramSolutionDocument{QuadraticProgramSolutionDocument(backend:runMetadata(for:model),model:model,solution:solution)} }
public struct NativeEducationalQuadraticProgrammingBackend:QuadraticProgrammingBackend{public init(){};public var capabilities:SolverCapabilities{SolverCapabilities(backendKind:.nativeEducational,solves:true,validates:true,exportsStructuredSolution:true,notes:["Active-set KKT enumeration for continuous convex/concave QP; bounded fixture-scale enumeration for diagonal integer QP."])};public func solve(_ model:QuadraticProgram,options _:SolverOptions=SolverOptions())throws->QuadraticProgramSolution{try QuadraticProgrammingSolver.solve(model)};public func runMetadata(for model:QuadraticProgram)->SolverRunMetadata{let integer=model.variableTypes.contains{$0 != .continuous};return SolverRunMetadata(backendKind:.nativeEducational,algorithm:integer ? "diagonalIntegerQuadraticEnumeration":"activeSetKKTEnumeration",exactness:integer ? .fixtureScale:.exact,notes:integer ? ["Exact within mathematically derived separable objective bounds for supported diagonal fixture-scale models."]:["Requires strictly convex minimization or strictly concave maximization."])}}
public struct ValidateOnlyQuadraticProgrammingBackend:QuadraticProgrammingBackend{public init(){};public var capabilities:SolverCapabilities{SolverCapabilities(backendKind:.validateOnly,solves:false,validates:true,exportsStructuredSolution:false)};public func solve(_ model:QuadraticProgram,options _:SolverOptions=SolverOptions())throws->QuadraticProgramSolution{throw QuadraticProgrammingError.invalidModel("validateOnly backend does not solve quadratic programs")};public func runMetadata(for _:QuadraticProgram)->SolverRunMetadata{SolverRunMetadata(backendKind:.validateOnly,algorithm:"validationOnly",exactness:.exact)}}
public enum QuadraticProgrammingBackends{public static func backend(for kind:SolverBackendKind)->(any QuadraticProgrammingBackend)?{switch kind{case .nativeEducational:NativeEducationalQuadraticProgrammingBackend();case .validateOnly:ValidateOnlyQuadraticProgrammingBackend();case .externalHighPerformance:nil}}}
public enum QuadraticProgrammingJSON{public static func encodeModel(_ x:QuadraticProgram)throws->Data{try encoder.encode(x)};public static func decodeUncheckedModel(from x:Data)throws->QuadraticProgram{try JSONDecoder().decode(QuadraticProgram.self,from:x)};public static func decodeModel(from x:Data)throws->QuadraticProgram{let model=try decodeUncheckedModel(from:x);try QuadraticProgramValidator.validate(model);return model};public static func encodeSolution(_ x:QuadraticProgramSolutionDocument)throws->Data{try encoder.encode(x)};public static func decodeSolution(from x:Data)throws->QuadraticProgramSolutionDocument{try JSONDecoder().decode(QuadraticProgramSolutionDocument.self,from:x)};public static func encodeValidation(_ x:QuadraticProgramValidationDocument)throws->Data{try encoder.encode(x)};private static var encoder:JSONEncoder{let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];return e}}
