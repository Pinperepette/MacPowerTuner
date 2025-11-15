import SwiftUI

struct PrivacySecurityView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var gatekeeperStatus = "Unknown"
    @State private var showingConfirmation = false
    @State private var confirmationAction: (() -> Void)?
    @State private var confirmationMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Gatekeeper", icon: "shield.lefthalf.filled") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Status:")
                            .font(.body)
                        Text(gatekeeperStatus)
                            .font(.body.monospacedDigit())
                            .foregroundColor(gatekeeperStatus == "Enabled" ? .green : .orange)
                        Spacer()
                        Button("Refresh") {
                            checkGatekeeperStatus()
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("Gatekeeper verifies apps before they run. Disabling allows unsigned apps to run.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: {
                            confirmationMessage = "Are you sure you want to disable Gatekeeper? This will allow unsigned apps to run."
                            confirmationAction = disableGatekeeper
                            showingConfirmation = true
                        }) {
                            Label("Disable Gatekeeper", systemImage: "lock.open")
                        }
                        .buttonStyle(.bordered)

                        Button(action: enableGatekeeper) {
                            Label("Enable Gatekeeper", systemImage: "lock")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            SectionCard(title: "DNS & Network", icon: "network") {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: flushDNS) {
                        Label("Flush DNS Cache", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Text("Clears DNS cache to resolve network issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            SectionCard(title: "System Access", icon: "hand.raised") {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: openPrivacySettings) {
                        Label("Open Privacy & Security Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)

                    Text("Manage app permissions for camera, microphone, files, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .onAppear(perform: checkGatekeeperStatus)
        .alert("Confirm Action", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                confirmationAction?()
            }
        } message: {
            Text(confirmationMessage)
        }
    }

    private func checkGatekeeperStatus() {
        Task {
            do {
                let output = try await CommandExecutor.shared.execute("/usr/sbin/spctl", arguments: ["--status"], sudo: false)
                let status = output.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    gatekeeperStatus = status.contains("enabled") ? "Enabled" : "Disabled"
                }
                activityLog.log("Gatekeeper status: \(gatekeeperStatus)", type: .info)
            } catch {
                DispatchQueue.main.async {
                    gatekeeperStatus = "Unknown"
                }
                activityLog.log("Failed to check Gatekeeper status: \(error.localizedDescription)", type: .warning)
            }
        }
    }

    private func disableGatekeeper() {
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/sbin/spctl", arguments: ["--master-disable"], sudo: true)
                activityLog.log("Gatekeeper disabled", type: .warning)
                notificationManager.showSuccess(message: "Gatekeeper has been disabled")
                checkGatekeeperStatus()
            } catch {
                activityLog.log("Failed to disable Gatekeeper: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to disable Gatekeeper. Administrator privileges required.")
            }
        }
    }

    private func enableGatekeeper() {
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/sbin/spctl", arguments: ["--master-enable"], sudo: true)
                activityLog.log("Gatekeeper enabled", type: .success)
                notificationManager.showSuccess(message: "Gatekeeper has been enabled")
                checkGatekeeperStatus()
            } catch {
                activityLog.log("Failed to enable Gatekeeper: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to enable Gatekeeper. Administrator privileges required.")
            }
        }
    }

    private func flushDNS() {
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["killall", "-HUP", "mDNSResponder"], sudo: true)
                activityLog.log("DNS cache flushed successfully", type: .success)
                notificationManager.showSuccess(message: "DNS cache has been flushed")
            } catch {
                activityLog.log("Failed to flush DNS: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to flush DNS cache")
            }
        }
    }

    private func openPrivacySettings() {
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/open", arguments: ["x-apple.systempreferences:com.apple.preference.security?Privacy"])
                activityLog.log("Opening Privacy & Security settings", type: .info)
            } catch {
                activityLog.log("Failed to open settings: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }
}

#Preview {
    PrivacySecurityView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
