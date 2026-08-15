import QSBCore

extension QSBCLI {
    static func linearProgrammingBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any LinearProgrammingBackend {
        guard let selectedBackend = LinearProgrammingBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }

    static func schedulingBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any SchedulingBackend {
        guard let selectedBackend = SchedulingBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }

    static func queuingBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any QueuingBackend {
        guard let selectedBackend = QueuingBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }
}
