import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType

    enum LogType {
        case info
        case success
        case error
        case warning
    }
}

class ActivityLog: ObservableObject {
    @Published var entries: [LogEntry] = []

    func log(_ message: String, type: LogEntry.LogType = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, type: type)
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)

            // Keep only last 100 entries
            if self.entries.count > 100 {
                self.entries = Array(self.entries.prefix(100))
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }
}
