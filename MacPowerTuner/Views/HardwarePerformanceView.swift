import SwiftUI

struct HardwarePerformanceView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var batteryInfo = "Loading..."
    @State private var sleepAssertions = ""
    @State private var topProcesses = ""
    @State private var selectedProcess = ""
    @State private var showingKillConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Battery Information", icon: "battery.100") {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView {
                        Text(batteryInfo)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)

                    Button(action: loadBatteryInfo) {
                        Label("Refresh Battery Info", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }

            SectionCard(title: "Sleep Preventers", icon: "moon.zzz") {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: loadSleepAssertions) {
                        Label("Show Processes Preventing Sleep", systemImage: "list.bullet")
                    }
                    .buttonStyle(.bordered)

                    if !sleepAssertions.isEmpty {
                        ScrollView {
                            Text(sleepAssertions)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 150)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                    }
                }
            }

            SectionCard(title: "Process Manager", icon: "cpu") {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: loadTopProcesses) {
                        Label("Show Top Processes (CPU)", systemImage: "chart.bar")
                    }
                    .buttonStyle(.bordered)

                    if !topProcesses.isEmpty {
                        ScrollView {
                            Text(topProcesses)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                    }

                    Divider()

                    HStack {
                        TextField("Process name to kill", text: $selectedProcess)
                            .textFieldStyle(.roundedBorder)

                        Button(action: {
                            if !selectedProcess.isEmpty {
                                showingKillConfirmation = true
                            }
                        }) {
                            Label("Kill Process", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(selectedProcess.isEmpty)
                    }

                    Text("Warning: Killing processes can cause data loss")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            SectionCard(title: "Memory", icon: "memorychip") {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: purgeMemory) {
                        Label("Purge Memory (Free RAM)", systemImage: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.bordered)

                    Text("Forces macOS to free up inactive memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .onAppear(perform: loadBatteryInfo)
        .alert("Kill Process?", isPresented: $showingKillConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Kill", role: .destructive) {
                killProcess()
            }
        } message: {
            Text("Are you sure you want to kill '\(selectedProcess)'? This may cause data loss.")
        }
    }

    private func loadBatteryInfo() {
        Task {
            do {
                let output = try await CommandExecutor.shared.execute("/usr/bin/pmset", arguments: ["-g", "batt"])
                DispatchQueue.main.async {
                    batteryInfo = output
                }
                activityLog.log("Battery info loaded", type: .info)
            } catch {
                DispatchQueue.main.async {
                    batteryInfo = "Failed to load battery info"
                }
                activityLog.log("Failed to load battery info: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func loadSleepAssertions() {
        Task {
            do {
                let output = try await CommandExecutor.shared.execute("/usr/bin/pmset", arguments: ["-g", "assertions"])
                DispatchQueue.main.async {
                    sleepAssertions = output
                }
                activityLog.log("Sleep assertions loaded", type: .info)
            } catch {
                DispatchQueue.main.async {
                    sleepAssertions = "Failed to load sleep assertions"
                }
                activityLog.log("Failed to load sleep assertions: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func loadTopProcesses() {
        Task {
            do {
                let output = try await CommandExecutor.shared.execute("/usr/bin/top", arguments: ["-l", "1", "-n", "20", "-o", "cpu"])
                DispatchQueue.main.async {
                    topProcesses = output
                }
                activityLog.log("Top processes loaded", type: .info)
            } catch {
                DispatchQueue.main.async {
                    topProcesses = "Failed to load top processes"
                }
                activityLog.log("Failed to load processes: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func killProcess() {
        Task {
            do {
                try await CommandExecutor.shared.killProcess(name: selectedProcess)
                activityLog.log("Process '\(selectedProcess)' killed", type: .warning)
                notificationManager.showSuccess(message: "Process '\(selectedProcess)' has been terminated")
                selectedProcess = ""
                // Refresh process list
                loadTopProcesses()
            } catch {
                activityLog.log("Failed to kill process: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to kill process '\(selectedProcess)'")
            }
        }
    }

    private func purgeMemory() {
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["purge"], sudo: true)
                activityLog.log("Memory purged successfully", type: .success)
                notificationManager.showSuccess(message: "Memory has been purged")
            } catch {
                activityLog.log("Failed to purge memory: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Failed to purge memory. Administrator privileges required.")
            }
        }
    }
}

#Preview {
    HardwarePerformanceView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
