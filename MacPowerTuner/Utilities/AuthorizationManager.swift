import Foundation
import Security

class AuthorizationManager {
    static let shared = AuthorizationManager()

    private var authorizationRef: AuthorizationRef?

    private init() {
        requestAuthorization()
    }

    func requestAuthorization() {
        var authRef: AuthorizationRef?

        let status = AuthorizationCreate(nil, nil, [], &authRef)

        if status == errAuthorizationSuccess {
            self.authorizationRef = authRef
        }
    }

    func getAuthorizationRef() -> AuthorizationRef? {
        if authorizationRef == nil {
            requestAuthorization()
        }
        return authorizationRef
    }

    func executeWithPrivileges(command: String, arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let authRef = self.authorizationRef else {
                completion(.failure(CommandError.authorizationFailed))
                return
            }

            // Use osascript with administrator privileges
            let script = """
            do shell script "\(command) \(arguments.joined(separator: " "))" with administrator privileges
            """

            let task = Process()
            let pipe = Pipe()

            task.standardOutput = pipe
            task.standardError = pipe
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus == 0 {
                    completion(.success(output))
                } else {
                    completion(.failure(CommandError.executionFailed(output)))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    deinit {
        if let authRef = authorizationRef {
            AuthorizationFree(authRef, [])
        }
    }
}
