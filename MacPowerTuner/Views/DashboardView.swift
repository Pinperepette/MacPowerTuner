import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var cpuUsage: Double = 0.0
    @State private var memoryUsage: Double = 0.0
    @State private var diskUsage: Double = 0.0
    @State private var uptime: String = "Loading..."
    @State private var systemVersion: String = "Loading..."
    @State private var refreshTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Welcome section
                VStack(alignment: .leading, spacing: 8) {
                    Text("MacPowerTuner")
                        .font(.system(size: 32, weight: .bold))
                    Text("System Overview & Quick Actions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // System Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "CPU Usage",
                        value: String(format: "%.1f%%", cpuUsage),
                        icon: "cpu",
                        color: cpuUsage > 80 ? .red : cpuUsage > 50 ? .orange : .green
                    )

                    StatCard(
                        title: "Memory",
                        value: String(format: "%.1f%%", memoryUsage),
                        icon: "memorychip",
                        color: memoryUsage > 80 ? .red : memoryUsage > 50 ? .orange : .green
                    )

                    StatCard(
                        title: "Disk Space",
                        value: String(format: "%.1f%%", diskUsage),
                        icon: "internaldrive",
                        color: diskUsage > 90 ? .red : diskUsage > 70 ? .orange : .green
                    )

                    StatCard(
                        title: "Uptime",
                        value: uptime,
                        icon: "clock",
                        color: .blue
                    )
                }

                // System Info
                SectionCard(title: "System Information", icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "macOS Version", value: systemVersion)
                        InfoRow(label: "Model", value: getMacModel())
                        InfoRow(label: "Processor", value: getProcessorInfo())
                    }
                }

                // Quick Actions
                SectionCard(title: "Quick Actions", icon: "bolt.circle") {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            QuickActionButton(
                                title: "Purge RAM",
                                icon: "arrow.clockwise",
                                color: .blue
                            ) {
                                purgeMemory()
                            }

                            QuickActionButton(
                                title: "Flush DNS",
                                icon: "network",
                                color: .green
                            ) {
                                flushDNS()
                            }
                        }

                        HStack(spacing: 12) {
                            QuickActionButton(
                                title: "Restart Finder",
                                icon: "folder",
                                color: .orange
                            ) {
                                restartFinder()
                            }

                            QuickActionButton(
                                title: "Restart Dock",
                                icon: "dock.rectangle",
                                color: .purple
                            ) {
                                restartDock()
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadSystemStats()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    private func loadSystemStats() {
        Task {
            await loadCPUUsage()
            await loadMemoryUsage()
            await loadDiskUsage()
            await loadUptime()
            loadSystemVersion()
        }
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            loadSystemStats()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadCPUUsage() async {
        do {
            let output = try await CommandExecutor.shared.execute("/usr/bin/top", arguments: ["-l", "1", "-n", "0"])
            if let cpuLine = output.split(separator: "\n").first(where: { $0.contains("CPU usage") }) {
                let components = cpuLine.split(separator: " ")
                if let userIndex = components.firstIndex(of: "user,"),
                   userIndex > 0,
                   let userPercent = Double(components[userIndex - 1].trimmingCharacters(in: CharacterSet(charactersIn: "%"))) {
                    DispatchQueue.main.async {
                        cpuUsage = userPercent
                    }
                }
            }
        } catch {
            print("Failed to load CPU usage: \(error)")
        }
    }

    private func loadMemoryUsage() async {
        do {
            let output = try await CommandExecutor.shared.execute("/usr/bin/vm_stat")
            let lines = output.split(separator: "\n")

            var pageSize: Double = 4096
            var free: Double = 0
            var active: Double = 0
            var inactive: Double = 0
            var wired: Double = 0

            for line in lines {
                if line.contains("page size of") {
                    if let size = line.split(separator: " ").last.flatMap({ Double($0) }) {
                        pageSize = size
                    }
                } else if line.contains("Pages free") {
                    free = extractNumber(from: String(line))
                } else if line.contains("Pages active") {
                    active = extractNumber(from: String(line))
                } else if line.contains("Pages inactive") {
                    inactive = extractNumber(from: String(line))
                } else if line.contains("Pages wired down") {
                    wired = extractNumber(from: String(line))
                }
            }

            let totalBytes = (free + active + inactive + wired) * pageSize
            let usedBytes = (active + inactive + wired) * pageSize
            let percent = (usedBytes / totalBytes) * 100

            DispatchQueue.main.async {
                memoryUsage = percent
            }
        } catch {
            print("Failed to load memory usage: \(error)")
        }
    }

    private func extractNumber(from string: String) -> Double {
        let components = string.split(separator: ":")
        guard components.count > 1 else { return 0 }
        let number = components[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
        return Double(number) ?? 0
    }

    private func loadDiskUsage() async {
        do {
            let output = try await CommandExecutor.shared.execute("/bin/df", arguments: ["-h", "/"])
            let lines = output.split(separator: "\n")
            if lines.count > 1 {
                let components = lines[1].split(separator: " ").filter { !$0.isEmpty }
                if components.count >= 5 {
                    let percentStr = String(components[4]).replacingOccurrences(of: "%", with: "")
                    if let percent = Double(percentStr) {
                        DispatchQueue.main.async {
                            diskUsage = percent
                        }
                    }
                }
            }
        } catch {
            print("Failed to load disk usage: \(error)")
        }
    }

    private func loadUptime() async {
        do {
            let output = try await CommandExecutor.shared.execute("/usr/bin/uptime")
            let uptimeStr = output.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                uptime = parseUptime(uptimeStr)
            }
        } catch {
            DispatchQueue.main.async {
                uptime = "N/A"
            }
        }
    }

    private func parseUptime(_ uptime: String) -> String {
        if let range = uptime.range(of: "up\\s+(.+?),\\s+\\d+\\s+user", options: .regularExpression) {
            return String(uptime[range]).replacingOccurrences(of: "up ", with: "").components(separatedBy: ",")[0].trimmingCharacters(in: .whitespaces)
        }
        return "N/A"
    }

    private func loadSystemVersion() {
        let version = ProcessInfo.processInfo.operatingSystemVersionString
        systemVersion = version
    }

    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func getProcessorInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        return String(cString: brand)
    }

    // Quick Actions
    private func purgeMemory() {
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["purge"], sudo: true)
                activityLog.log("Memory purged successfully", type: .success)
                notificationManager.showSuccess(message: "Memory purged")
                await loadMemoryUsage()
            } catch {
                activityLog.log("Failed to purge memory: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func flushDNS() {
        Task {
            do {
                try await CommandExecutor.shared.execute("/usr/bin/sudo", arguments: ["killall", "-HUP", "mDNSResponder"], sudo: true)
                activityLog.log("DNS cache flushed", type: .success)
                notificationManager.showSuccess(message: "DNS cache flushed")
            } catch {
                activityLog.log("Failed to flush DNS: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func restartFinder() {
        Task {
            do {
                try await CommandExecutor.shared.killProcess(name: "Finder")
                activityLog.log("Finder restarted", type: .success)
                notificationManager.showSuccess(message: "Finder restarted")
            } catch {
                activityLog.log("Failed to restart Finder: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func restartDock() {
        Task {
            do {
                try await CommandExecutor.shared.killProcess(name: "Dock")
                activityLog.log("Dock restarted", type: .success)
                notificationManager.showSuccess(message: "Dock restarted")
            } catch {
                activityLog.log("Failed to restart Dock: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }
}

// Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
