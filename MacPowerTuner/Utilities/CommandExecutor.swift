import Foundation

class CommandExecutor {
    static let shared = CommandExecutor()

    private init() {}

    @discardableResult
    func execute(_ command: String, arguments: [String] = [], sudo: Bool = false) async throws -> String {
        if sudo {
            return try await executeWithSudo(command: command, arguments: arguments)
        } else {
            return try await executeNormal(command: command, arguments: arguments)
        }
    }

    private func executeNormal(command: String, arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()

            task.standardOutput = pipe
            task.standardError = pipe
            task.executableURL = URL(fileURLWithPath: command)
            task.arguments = arguments

            do {
                try task.run()

                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: CommandError.executionFailed(output))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func executeWithSudo(command: String, arguments: [String]) async throws -> String {
        // Use osascript with administrator privileges
        let script = """
        do shell script "\(command) \(arguments.joined(separator: " "))" with administrator privileges
        """

        return try await executeNormal(command: "/usr/bin/osascript", arguments: ["-e", script])
    }

    func executeDefaults(domain: String, key: String, value: String, type: String = "string") async throws {
        let arguments: [String]
        switch type {
        case "bool":
            arguments = ["write", domain, key, "-bool", value]
        case "float":
            arguments = ["write", domain, key, "-float", value]
        case "int":
            arguments = ["write", domain, key, "-int", value]
        default:
            arguments = ["write", domain, key, value]
        }

        try await execute("/usr/bin/defaults", arguments: arguments)
    }

    func readDefaults(domain: String, key: String) async throws -> String {
        try await execute("/usr/bin/defaults", arguments: ["read", domain, key])
    }

    func killProcess(name: String) async throws {
        try await execute("/usr/bin/killall", arguments: [name])
    }
}

enum CommandError: LocalizedError {
    case executionFailed(String)
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .executionFailed(let output):
            return "Command execution failed: \(output)"
        case .authorizationFailed:
            return "Authorization failed"
        }
    }
}
