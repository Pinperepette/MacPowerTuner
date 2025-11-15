import SwiftUI

struct SystemInfoView: View {
    @EnvironmentObject var activityLog: ActivityLog

    @State private var hardwareInfo: [InfoSection] = []
    @State private var systemInfo: [InfoSection] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView("Loading system information...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    // Hardware Information
                    SectionCard(title: "Hardware Information", icon: "desktopcomputer") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(hardwareInfo) { section in
                                InfoSectionView(section: section)
                                if section.id != hardwareInfo.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    // System Information
                    SectionCard(title: "System Information", icon: "gearshape.2") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(systemInfo) { section in
                                InfoSectionView(section: section)
                                if section.id != systemInfo.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    // Actions
                    SectionCard(title: "Actions", icon: "square.and.arrow.up") {
                        HStack(spacing: 12) {
                            Button(action: copyAllInfo) {
                                Label("Copy All Info", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)

                            Button(action: exportToFile) {
                                Label("Export to File", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)

                            Button(action: loadAllInfo) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            if isLoading {
                loadAllInfo()
            }
        }
    }

    private func loadAllInfo() {
        isLoading = true

        Task {
            await loadHardwareInfo()
            await loadSystemInfo()

            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }

    private func loadHardwareInfo() async {
        var sections: [InfoSection] = []

        // Model & Identifier
        sections.append(InfoSection(
            title: "Model",
            items: [
                InfoItem(key: "Model Name", value: getMacModel()),
                InfoItem(key: "Model Identifier", value: getModelIdentifier()),
                InfoItem(key: "Serial Number", value: getSerialNumber())
            ]
        ))

        // Processor
        sections.append(InfoSection(
            title: "Processor",
            items: [
                InfoItem(key: "CPU", value: getProcessorBrand()),
                InfoItem(key: "Cores", value: "\(getProcessorCores()) cores"),
                InfoItem(key: "Architecture", value: getArchitecture())
            ]
        ))

        // Memory
        let memInfo = await getMemoryInfo()
        sections.append(InfoSection(
            title: "Memory",
            items: memInfo
        ))

        // Graphics
        let gpuInfo = await getGPUInfo()
        if !gpuInfo.isEmpty {
            sections.append(InfoSection(
                title: "Graphics",
                items: gpuInfo
            ))
        }

        // Storage
        let storageInfo = await getStorageInfo()
        sections.append(InfoSection(
            title: "Storage",
            items: storageInfo
        ))

        DispatchQueue.main.async {
            self.hardwareInfo = sections
        }
    }

    private func loadSystemInfo() async {
        var sections: [InfoSection] = []

        // Operating System
        sections.append(InfoSection(
            title: "Operating System",
            items: [
                InfoItem(key: "macOS Version", value: getOSVersion()),
                InfoItem(key: "Build Number", value: getBuildNumber()),
                InfoItem(key: "Kernel Version", value: getKernelVersion())
            ]
        ))

        // Network
        let networkInfo = await getNetworkInfo()
        sections.append(InfoSection(
            title: "Network",
            items: networkInfo
        ))

        // Boot & Uptime
        let bootInfo = await getBootInfo()
        sections.append(InfoSection(
            title: "System Status",
            items: bootInfo
        ))

        DispatchQueue.main.async {
            self.systemInfo = sections
        }
    }

    // Hardware Info Functions
    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func getModelIdentifier() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }

        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            return String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? "Unknown"
        }
        return "Unknown"
    }

    private func getSerialNumber() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }

        if let serialData = IORegistryEntryCreateCFProperty(service, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? String {
            return serialData
        }
        return "Unknown"
    }

    private func getProcessorBrand() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        return String(cString: brand)
    }

    private func getProcessorCores() -> Int {
        var cores: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.physicalcpu", &cores, &size, nil, 0)
        return cores
    }

    private func getArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    private func getMemoryInfo() async -> [InfoItem] {
        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)

        let totalGB = Double(totalMemory) / 1_073_741_824.0

        return [
            InfoItem(key: "Total RAM", value: String(format: "%.0f GB", totalGB)),
            InfoItem(key: "Type", value: "DDR4/DDR5") // Simplified
        ]
    }

    private func getGPUInfo() async -> [InfoItem] {
        do {
            let output = try await CommandExecutor.shared.execute("/usr/sbin/system_profiler", arguments: ["SPDisplaysDataType"])
            if let gpuLine = output.split(separator: "\n").first(where: { $0.contains("Chipset Model") }) {
                let gpu = gpuLine.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "Unknown"
                return [InfoItem(key: "GPU", value: gpu)]
            }
        } catch {}
        return []
    }

    private func getStorageInfo() async -> [InfoItem] {
        do {
            let output = try await CommandExecutor.shared.execute("/bin/df", arguments: ["-h", "/"])
            let lines = output.split(separator: "\n")
            if lines.count > 1 {
                let components = lines[1].split(separator: " ").filter { !$0.isEmpty }
                if components.count >= 5 {
                    return [
                        InfoItem(key: "Total Size", value: String(components[1])),
                        InfoItem(key: "Used", value: String(components[2])),
                        InfoItem(key: "Available", value: String(components[3])),
                        InfoItem(key: "Usage", value: String(components[4]))
                    ]
                }
            }
        } catch {}
        return []
    }

    // System Info Functions
    private func getOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private func getBuildNumber() -> String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    private func getKernelVersion() -> String {
        var size = 0
        sysctlbyname("kern.osrelease", nil, &size, nil, 0)
        var release = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osrelease", &release, &size, nil, 0)
        return String(cString: release)
    }

    private func getNetworkInfo() async -> [InfoItem] {
        var items: [InfoItem] = []

        do {
            let output = try await CommandExecutor.shared.execute("/sbin/ifconfig", arguments: ["en0"])
            if let ipLine = output.split(separator: "\n").first(where: { $0.contains("inet ") && !$0.contains("inet6") }) {
                let components = ipLine.split(separator: " ")
                if let ipIndex = components.firstIndex(of: "inet"), ipIndex + 1 < components.count {
                    items.append(InfoItem(key: "Local IP", value: String(components[ipIndex + 1])))
                }
            }

            // Get MAC address
            if let macLine = output.split(separator: "\n").first(where: { $0.contains("ether") }) {
                let components = macLine.split(separator: " ")
                if components.count > 1 {
                    items.append(InfoItem(key: "MAC Address", value: String(components[1])))
                }
            }

            // Get public IP
            let publicIP = try await CommandExecutor.shared.execute("/usr/bin/curl", arguments: ["-s", "https://api.ipify.org"])
            items.append(InfoItem(key: "Public IP", value: publicIP.trimmingCharacters(in: .whitespacesAndNewlines)))
        } catch {}

        return items
    }

    private func getBootInfo() async -> [InfoItem] {
        var items: [InfoItem] = []

        do {
            let uptimeOutput = try await CommandExecutor.shared.execute("/usr/bin/uptime")
            items.append(InfoItem(key: "Uptime", value: parseUptime(uptimeOutput)))

            let bootTime = try await CommandExecutor.shared.execute("/usr/sbin/sysctl", arguments: ["-n", "kern.boottime"])
            items.append(InfoItem(key: "Boot Time", value: bootTime.trimmingCharacters(in: .whitespacesAndNewlines)))
        } catch {}

        return items
    }

    private func parseUptime(_ uptime: String) -> String {
        if let range = uptime.range(of: "up\\s+(.+?),\\s+\\d+\\s+user", options: .regularExpression) {
            return String(uptime[range]).replacingOccurrences(of: "up ", with: "").components(separatedBy: ",")[0].trimmingCharacters(in: .whitespaces)
        }
        return "N/A"
    }

    // Actions
    private func copyAllInfo() {
        var text = "=== Mac System Information ===\n\n"

        text += "HARDWARE\n"
        for section in hardwareInfo {
            text += "\n\(section.title):\n"
            for item in section.items {
                text += "  \(item.key): \(item.value)\n"
            }
        }

        text += "\n\nSYSTEM\n"
        for section in systemInfo {
            text += "\n\(section.title):\n"
            for item in section.items {
                text += "  \(item.key): \(item.value)\n"
            }
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        activityLog.log("System information copied to clipboard", type: .success)
    }

    private func exportToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "system-info.txt"
        panel.allowedContentTypes = [.plainText]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                var text = "=== Mac System Information ===\n\n"

                text += "HARDWARE\n"
                for section in hardwareInfo {
                    text += "\n\(section.title):\n"
                    for item in section.items {
                        text += "  \(item.key): \(item.value)\n"
                    }
                }

                text += "\n\nSYSTEM\n"
                for section in systemInfo {
                    text += "\n\(section.title):\n"
                    for item in section.items {
                        text += "  \(item.key): \(item.value)\n"
                    }
                }

                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                    activityLog.log("System information exported to \(url.path)", type: .success)
                } catch {
                    activityLog.log("Failed to export: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
}

// Models
struct InfoSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [InfoItem]
}

struct InfoItem: Identifiable {
    let id = UUID()
    let key: String
    let value: String
}

// Supporting View
struct InfoSectionView: View {
    let section: InfoSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(section.items) { item in
                HStack {
                    Text(item.key)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(item.value)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SystemInfoView()
        .environmentObject(ActivityLog())
        .frame(width: 700)
}
