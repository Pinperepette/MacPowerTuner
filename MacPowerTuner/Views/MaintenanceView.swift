import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var isRunning = false
    @State private var showingConfirmation = false
    @State private var confirmationAction: (() -> Void)?
    @State private var confirmationTitle = ""
    @State private var confirmationMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Cache Management", icon: "trash") {
                VStack(alignment: .leading, spacing: 12) {
                    MaintenanceButton(
                        title: "Clear User Cache",
                        description: "Remove cached files from ~/Library/Caches",
                        icon: "folder.badge.minus",
                        isRunning: isRunning
                    ) {
                        confirmAction(
                            title: "Clear User Cache?",
                            message: "This will delete cached files. Apps may take longer to start the next time.",
                            action: clearUserCache
                        )
                    }

                    MaintenanceButton(
                        title: "Clear DNS Cache",
                        description: "Flush DNS resolver cache",
                        icon: "network",
                        isRunning: isRunning
                    ) {
                        flushDNSCache()
                    }

                    MaintenanceButton(
                        title: "Clear System Cache",
                        description: "Remove system-level cached files (requires admin)",
                        icon: "externaldrive.badge.minus",
                        isRunning: isRunning
                    ) {
                        confirmAction(
                            title: "Clear System Cache?",
                            message: "This requires administrator privileges and may affect system performance temporarily.",
                            action: clearSystemCache
                        )
                    }
                }
            }

            SectionCard(title: "System Database Rebuilds", icon: "arrow.triangle.2.circlepath") {
                VStack(alignment: .leading, spacing: 12) {
                    MaintenanceButton(
                        title: "Rebuild Launch Services",
                        description: "Fix file associations and default apps",
                        icon: "arrow.clockwise.circle",
                        isRunning: isRunning
                    ) {
                        confirmAction(
                            title: "Rebuild Launch Services?",
                            message: "This will reset file associations. Requires administrator privileges.",
                            action: rebuildLaunchServices
                        )
                    }

                    MaintenanceButton(
                        title: "Rebuild Spotlight Index",
                        description: "Re-index all files for Spotlight search",
                        icon: "magnifyingglass.circle",
                        isRunning: isRunning
                    ) {
                        confirmAction(
                            title: "Rebuild Spotlight?",
                            message: "This will take time and requires administrator privileges. Your Mac may be slow during indexing.",
                            action: rebuildSpotlight
                        )
                    }
                }
            }

            SectionCard(title: "Temporary Files", icon: "doc.badge.minus") {
                VStack(alignment: .leading, spacing: 12) {
                    MaintenanceButton(
                        title: "Clean Temporary Files",
                        description: "Remove files from /tmp and /var/tmp",
                        icon: "folder.badge.minus",
                        isRunning: isRunning
                    ) {
                        cleanTempFiles()
                    }

                    MaintenanceButton(
                        title: "Purge Memory",
                        description: "Force macOS to free inactive RAM",
                        icon: "memorychip",
                        isRunning: isRunning
                    ) {
                        purgeMemory()
                    }
                }
            }

            if isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Running maintenance task...")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            Spacer()
        }
        .alert(confirmationTitle, isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                confirmationAction?()
            }
        } message: {
            Text(confirmationMessage)
        }
    }

    private func confirmAction(title: String, message: String, action: @escaping () -> Void) {
        confirmationTitle = title
        confirmationMessage = message
        confirmationAction = action
        showingConfirmation = true
    }

    private func clearUserCache() {
        isRunning = true
        Task {
            do {
                let cachePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
                let items = try FileManager.default.contentsOfDirectory(at: cachePath, includingPropertiesForKeys: nil)

                for item in items {
                    try? FileManager.default.removeItem(at: item)
                }

                activityLog.log("User cache cleared", type: .success)
                notificationManager.showSuccess(message: "User cache has been cleared")
            } catch {
                activityLog.log("Failed to clear user cache: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }

    private func clearSystemCache() {
        isRunning = true
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["rm", "-rf", "/Library/Caches/*"], sudo: true)
                activityLog.log("System cache cleared", type: .success)
                notificationManager.showSuccess(message: "System cache has been cleared")
            } catch {
                activityLog.log("Failed to clear system cache: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to clear system cache. Administrator privileges required.")
            }
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }

    private func flushDNSCache() {
        isRunning = true
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["killall", "-HUP", "mDNSResponder"], sudo: true)
                activityLog.log("DNS cache flushed", type: .success)
                notificationManager.showSuccess(message: "DNS cache has been flushed")
            } catch {
                activityLog.log("Failed to flush DNS: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }

    private func rebuildLaunchServices() {
        isRunning = true
        Task {
            do {
                let command = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: [command, "-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"], sudo: true)
                activityLog.log("Launch Services database rebuilt", type: .success)
                notificationManager.showSuccess(message: "Launch Services has been rebuilt")
            } catch {
                activityLog.log("Failed to rebuild Launch Services: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to rebuild Launch Services. Administrator privileges required.")
            }
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }

    private func rebuildSpotlight() {
        isRunning = true
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["mdutil", "-E", "/"], sudo: true)
                activityLog.log("Spotlight index rebuild started", type: .success)
                notificationManager.showSuccess(message: "Spotlight indexing has started. This may take a while.")
            } catch {
                activityLog.log("Failed to rebuild Spotlight: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to rebuild Spotlight. Administrator privileges required.")
            }
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }

    private func cleanTempFiles() {
        isRunning = true
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["rm", "-rf", "/tmp/*"], sudo: true)
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["rm", "-rf", "/var/tmp/*"], sudo: true)
                activityLog.log("Temporary files cleaned", type: .success)
                notificationManager.showSuccess(message: "Temporary files have been removed")
            } catch {
                activityLog.log("Failed to clean temp files: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }

    private func purgeMemory() {
        isRunning = true
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["purge"], sudo: true)
                activityLog.log("Memory purged", type: .success)
                notificationManager.showSuccess(message: "Memory has been purged")
            } catch {
                activityLog.log("Failed to purge memory: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to purge memory. Administrator privileges required.")
            }
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }
}

struct MaintenanceButton: View {
    let title: String
    let description: String
    let icon: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: action) {
                HStack {
                    Image(systemName: icon)
                    Text(title)
                    Spacer()
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRunning)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MaintenanceView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
