import Foundation
public enum LinearProgramJSON {
    public static func decodeProgram(from data: Data) throws -> LinearProgram {
        let program = try decoder.decode(LinearProgram.self, from: data)
        try validate(program)
        return program
    }

    public static func encodeProgram(_ program: LinearProgram) throws -> Data {
        try encoder.encode(program)
    }

    public static func encodeSolution(_ solution: LinearProgramSolution) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }

    private static func validate(_ program: LinearProgram) throws {
        try LinearProgramValidator.validate(program)
    }
}
