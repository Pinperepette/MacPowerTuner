import SwiftUI

struct DockView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var autohideTime: Double = 0.5
    @State private var autohideDelay: Double = 0.5
    @State private var singleAppMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Auto-Hide Animation", icon: "dock.rectangle") {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Animation Speed")
                                .font(.body)
                            Spacer()
                            Text(String(format: "%.1fs", autohideTime))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $autohideTime, in: 0.0...2.0, step: 0.1)
                        Text("Time for Dock to show/hide (0 = instant)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Auto-Hide Delay")
                                .font(.body)
                            Spacer()
                            Text(String(format: "%.1fs", autohideDelay))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $autohideDelay, in: 0.0...2.0, step: 0.1)
                        Text("Delay before Dock appears (0 = no delay)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: applyDockTiming) {
                        Label("Apply Animation Settings", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            SectionCard(title: "Dock Behavior", icon: "square.grid.3x3") {
                VStack(alignment: .leading, spacing: 16) {
                    ToggleRow(
                        title: "Single App Mode",
                        description: "Hide all other apps when clicking a Dock icon",
                        isOn: $singleAppMode,
                        action: toggleSingleAppMode
                    )
                }
            }

            SectionCard(title: "Apply Changes", icon: "arrow.clockwise") {
                Button(action: restartDock) {
                    Label("Restart Dock", systemImage: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .help("Restart Dock to apply all changes")
            }

            Spacer()
        }
        .onAppear(perform: loadCurrentSettings)
    }

    private func loadCurrentSettings() {
        Task {
            do {
                let timeOutput = try await CommandExecutor.shared.readDefaults(domain: "com.apple.dock", key: "autohide-time-modifier")
                autohideTime = Double(timeOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.5

                let delayOutput = try await CommandExecutor.shared.readDefaults(domain: "com.apple.dock", key: "autohide-delay")
                autohideDelay = Double(delayOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.5

                singleAppMode = try await readBoolDefault("com.apple.dock", "single-app")
            } catch {
                // Use defaults if settings don't exist
            }
        }
    }

    private func readBoolDefault(_ domain: String, _ key: String) async throws -> Bool {
        let output = try await CommandExecutor.shared.readDefaults(domain: domain, key: key)
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    private func applyDockTiming() {
        Task {
            do {
                try await CommandExecutor.shared.executeDefaults(
                    domain: "com.apple.dock",
                    key: "autohide-time-modifier",
                    value: String(autohideTime),
                    type: "float"
                )
                try await CommandExecutor.shared.executeDefaults(
                    domain: "com.apple.dock",
                    key: "autohide-delay",
                    value: String(autohideDelay),
                    type: "float"
                )
                activityLog.log("Dock animation settings applied", type: .success)
                notificationManager.showSuccess(message: "Dock animation settings updated. Restart Dock to apply.")
            } catch {
                activityLog.log("Failed to apply Dock settings: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func toggleSingleAppMode() {
        Task {
            do {
                try await CommandExecutor.shared.executeDefaults(
                    domain: "com.apple.dock",
                    key: "single-app",
                    value: singleAppMode ? "true" : "false",
                    type: "bool"
                )
                activityLog.log("Single app mode \(singleAppMode ? "enabled" : "disabled")", type: .success)
                notificationManager.showSuccess(message: "Single app mode updated")
            } catch {
                activityLog.log("Failed to toggle single app mode: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
                singleAppMode.toggle()
            }
        }
    }

    private func restartDock() {
        Task {
            do {
                try await CommandExecutor.shared.killProcess(name: "Dock")
                activityLog.log("Dock restarted successfully", type: .success)
                notificationManager.showSuccess(message: "Dock has been restarted")
            } catch {
                activityLog.log("Failed to restart Dock: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }
}

#Preview {
    DockView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
