import SwiftUI

struct FinderView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var showHiddenFiles = false
    @State private var showFullPath = false
    @State private var showExtensions = false
    @State private var showPathBar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "File Visibility", icon: "eye") {
                VStack(alignment: .leading, spacing: 16) {
                    ToggleRow(
                        title: "Show Hidden Files",
                        description: "Display hidden files and folders in Finder",
                        isOn: $showHiddenFiles,
                        action: toggleHiddenFiles
                    )

                    ToggleRow(
                        title: "Show File Extensions",
                        description: "Display file extensions for all files",
                        isOn: $showExtensions,
                        action: toggleFileExtensions
                    )
                }
            }

            SectionCard(title: "Finder Path Options", icon: "arrow.triangle.branch") {
                VStack(alignment: .leading, spacing: 16) {
                    ToggleRow(
                        title: "Show Full Path in Title",
                        description: "Display complete POSIX path in Finder title bar",
                        isOn: $showFullPath,
                        action: toggleFullPath
                    )

                    ToggleRow(
                        title: "Show Path Bar",
                        description: "Display path bar at bottom of Finder windows",
                        isOn: $showPathBar,
                        action: togglePathBar
                    )
                }
            }

            SectionCard(title: "Apply Changes", icon: "arrow.clockwise") {
                Button(action: restartFinder) {
                    Label("Restart Finder", systemImage: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .help("Restart Finder to apply all changes")
            }

            Spacer()
        }
        .onAppear(perform: loadCurrentSettings)
    }

    private func loadCurrentSettings() {
        Task {
            do {
                showHiddenFiles = try await readBoolDefault("com.apple.finder", "AppleShowAllFiles")
                showFullPath = try await readBoolDefault("com.apple.finder", "_FXShowPosixPathInTitle")
                showExtensions = try await readBoolDefault("NSGlobalDomain", "AppleShowAllExtensions")
                showPathBar = try await readBoolDefault("com.apple.finder", "ShowPathbar")
            } catch {
                // Defaults don't exist yet, keep false
            }
        }
    }

    private func readBoolDefault(_ domain: String, _ key: String) async throws -> Bool {
        let output = try await CommandExecutor.shared.readDefaults(domain: domain, key: key)
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    private func toggleHiddenFiles() {
        Task {
            do {
                try await CommandExecutor.shared.executeDefaults(
                    domain: "com.apple.finder",
                    key: "AppleShowAllFiles",
                    value: showHiddenFiles ? "true" : "false",
                    type: "bool"
                )
                activityLog.log("Hidden files \(showHiddenFiles ? "shown" : "hidden")", type: .success)
                notificationManager.showSuccess(message: "Hidden files setting updated")
            } catch {
                activityLog.log("Failed to toggle hidden files: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
                showHiddenFiles.toggle() // Revert on error
            }
        }
    }

    private func toggleFullPath() {
        Task {
            do {
                try await CommandExecutor.shared.executeDefaults(
                    domain: "com.apple.finder",
                    key: "_FXShowPosixPathInTitle",
                    value: showFullPath ? "true" : "false",
                    type: "bool"
                )
                activityLog.log("Full path in title \(showFullPath ? "enabled" : "disabled")", type: .success)
                notificationManager.showSuccess(message: "Path display setting updated")
            } catch {
                activityLog.log("Failed to toggle full path: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
                showFullPath.toggle()
            }
        }
    }

    private func toggleFileExtensions() {
        Task {
            do {
                try await CommandExecutor.shared.executeDefaults(
                    domain: "NSGlobalDomain",
                    key: "AppleShowAllExtensions",
                    value: showExtensions ? "true" : "false",
                    type: "bool"
                )
                activityLog.log("File extensions \(showExtensions ? "shown" : "hidden")", type: .success)
                notificationManager.showSuccess(message: "File extensions setting updated")
            } catch {
                activityLog.log("Failed to toggle extensions: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
                showExtensions.toggle()
            }
        }
    }

    private func togglePathBar() {
        Task {
            do {
                try await CommandExecutor.shared.executeDefaults(
                    domain: "com.apple.finder",
                    key: "ShowPathbar",
                    value: showPathBar ? "true" : "false",
                    type: "bool"
                )
                activityLog.log("Path bar \(showPathBar ? "shown" : "hidden")", type: .success)
                notificationManager.showSuccess(message: "Path bar setting updated")
            } catch {
                activityLog.log("Failed to toggle path bar: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
                showPathBar.toggle()
            }
        }
    }

    private func restartFinder() {
        Task {
            do {
                try await CommandExecutor.shared.killProcess(name: "Finder")
                activityLog.log("Finder restarted successfully", type: .success)
                notificationManager.showSuccess(message: "Finder has been restarted")
            } catch {
                activityLog.log("Failed to restart Finder: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }
}

// Reusable components
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }

            content
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { _ in
                    action()
                }
        }
    }
}

#Preview {
    FinderView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
