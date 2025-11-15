import SwiftUI

struct NetworkToolsView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var localIP = "Loading..."
    @State private var publicIP = "Loading..."
    @State private var activeConnections = ""
    @State private var pingTarget = "8.8.8.8"
    @State private var pingResult = ""
    @State private var isMonitoring = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "IP Information", icon: "globe") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Local IP:")
                            .font(.body)
                        Text(localIP)
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                        Spacer()
                    }

                    HStack {
                        Text("Public IP:")
                            .font(.body)
                        Text(publicIP)
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                        Spacer()
                        Button("Refresh") {
                            loadIPAddresses()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            SectionCard(title: "Active Connections", icon: "network") {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: loadActiveConnections) {
                        Label("Show Active Connections", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    if !activeConnections.isEmpty {
                        ScrollView {
                            Text(activeConnections)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                    }
                }
            }

            SectionCard(title: "Network Tools", icon: "wifi") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        TextField("Host to ping (e.g., 8.8.8.8)", text: $pingTarget)
                            .textFieldStyle(.roundedBorder)

                        Button(action: performPing) {
                            Label("Ping", systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.bordered)
                    }

                    if !pingResult.isEmpty {
                        ScrollView {
                            Text(pingResult)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 150)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                    }

                    Divider()

                    Button(action: resetNetworkStack) {
                        Label("Reset Network Stack", systemImage: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.bordered)

                    Text("Restarts network services (may disconnect temporarily)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .onAppear(perform: loadIPAddresses)
    }

    private func loadIPAddresses() {
        Task {
            // Get local IP
            do {
                let output = try await CommandExecutor.shared.execute("/sbin/ifconfig", arguments: ["en0"])
                if let ipLine = output.split(separator: "\n").first(where: { $0.contains("inet ") && !$0.contains("inet6") }) {
                    let components = ipLine.split(separator: " ")
                    if let ipIndex = components.firstIndex(of: "inet"), ipIndex + 1 < components.count {
                        DispatchQueue.main.async {
                            localIP = String(components[ipIndex + 1])
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    localIP = "Not available"
                }
            }

            // Get public IP
            do {
                let output = try await CommandExecutor.shared.execute("/usr/bin/curl", arguments: ["-s", "https://api.ipify.org"])
                DispatchQueue.main.async {
                    publicIP = output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                DispatchQueue.main.async {
                    publicIP = "Not available"
                }
            }

            activityLog.log("IP addresses loaded", type: .info)
        }
    }

    private func loadActiveConnections() {
        Task {
            do {
                let output = try await CommandExecutor.shared.execute("/usr/sbin/lsof", arguments: ["-i", "-P", "-n"])
                DispatchQueue.main.async {
                    activeConnections = output
                }
                activityLog.log("Active connections loaded", type: .info)
            } catch {
                activityLog.log("Failed to load connections: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func performPing() {
        pingResult = "Pinging \(pingTarget)...\n"

        Task {
            do {
                let output = try await CommandExecutor.shared.execute("/sbin/ping", arguments: ["-c", "4", pingTarget])
                DispatchQueue.main.async {
                    pingResult = output
                }
                activityLog.log("Ping to \(pingTarget) completed", type: .success)
            } catch {
                DispatchQueue.main.async {
                    pingResult = "Ping failed: \(error.localizedDescription)"
                }
                activityLog.log("Ping failed: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func resetNetworkStack() {
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["ifconfig", "en0", "down"], sudo: true)
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["ifconfig", "en0", "up"], sudo: true)
                activityLog.log("Network stack reset successfully", type: .success)
                notificationManager.showSuccess(message: "Network stack has been reset")
                // Reload IPs after reset
                try await Task.sleep(nanoseconds: 2_000_000_000)
                loadIPAddresses()
            } catch {
                activityLog.log("Failed to reset network stack: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to reset network stack. Administrator privileges required.")
            }
        }
    }
}

#Preview {
    NetworkToolsView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
