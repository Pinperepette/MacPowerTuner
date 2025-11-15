import SwiftUI
import ServiceManagement

struct StartupItemsView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var loginItems: [StartupItem] = []
    @State private var launchAgents: [StartupItem] = []
    @State private var launchDaemons: [StartupItem] = []
    @State private var isLoading = true
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab Selector
            Picker("", selection: $selectedTab) {
                Text("Login Items").tag(0)
                Text("Launch Agents").tag(1)
                Text("Launch Daemons").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if isLoading {
                ProgressView("Loading startup items...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if selectedTab == 0 {
                            StartupItemsList(
                                items: loginItems,
                                title: "Login Items",
                                description: "Apps that start when you log in",
                                onToggle: toggleLoginItem,
                                onRemove: removeLoginItem
                            )
                        } else if selectedTab == 1 {
                            StartupItemsList(
                                items: launchAgents,
                                title: "Launch Agents",
                                description: "User-level background processes",
                                onToggle: toggleLaunchAgent,
                                onRemove: removeLaunchAgent
                            )
                        } else {
                            StartupItemsList(
                                items: launchDaemons,
                                title: "Launch Daemons",
                                description: "System-level background processes (requires sudo)",
                                onToggle: toggleLaunchDaemon,
                                onRemove: removeLaunchDaemon
                            )
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Footer with actions
            HStack {
                Button(action: loadAllItems) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("\(totalEnabledCount) enabled, \(totalDisabledCount) disabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .onAppear {
            if isLoading {
                loadAllItems()
            }
        }
    }

    private var totalEnabledCount: Int {
        let items = selectedTab == 0 ? loginItems : selectedTab == 1 ? launchAgents : launchDaemons
        return items.filter { $0.isEnabled }.count
    }

    private var totalDisabledCount: Int {
        let items = selectedTab == 0 ? loginItems : selectedTab == 1 ? launchAgents : launchDaemons
        return items.filter { !$0.isEnabled }.count
    }

    private func loadAllItems() {
        isLoading = true

        Task {
            await loadLoginItems()
            await loadLaunchAgents()
            await loadLaunchDaemons()

            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }

    private func loadLoginItems() async {
        // For modern macOS, we need to use different approach
        // This is a simplified version
        var items: [StartupItem] = []

        do {
            let output = try await CommandExecutor.shared.execute("/usr/bin/osascript", arguments: ["-e", "tell application \"System Events\" to get the name of every login item"])
            let names = output.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            for name in names {
                items.append(StartupItem(
                    name: name,
                    path: "",
                    isEnabled: true,
                    type: .loginItem
                ))
            }
        } catch {
            activityLog.log("Failed to load login items: \(error.localizedDescription)", type: .warning)
        }

        DispatchQueue.main.async {
            self.loginItems = items
        }
    }

    private func loadLaunchAgents() async {
        var items: [StartupItem] = []

        let userAgentsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        let systemAgentsPath = "/Library/LaunchAgents"

        items += await loadPlistsFrom(path: userAgentsPath.path, type: .launchAgent)
        items += await loadPlistsFrom(path: systemAgentsPath, type: .launchAgent)

        DispatchQueue.main.async {
            self.launchAgents = items.sorted { $0.name < $1.name }
        }
    }

    private func loadLaunchDaemons() async {
        var items: [StartupItem] = []

        let daemonsPath = "/Library/LaunchDaemons"
        items += await loadPlistsFrom(path: daemonsPath, type: .launchDaemon)

        DispatchQueue.main.async {
            self.launchDaemons = items.sorted { $0.name < $1.name }
        }
    }

    private func loadPlistsFrom(path: String, type: StartupItemType) async -> [StartupItem] {
        var items: [StartupItem] = []

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return items
        }

        for file in files where file.hasSuffix(".plist") {
            let fullPath = (path as NSString).appendingPathComponent(file)
            let name = (file as NSString).deletingPathExtension

            // Check if enabled
            let isEnabled = await checkIfEnabled(name: name, type: type)

            items.append(StartupItem(
                name: name,
                path: fullPath,
                isEnabled: isEnabled,
                type: type
            ))
        }

        return items
    }

    private func checkIfEnabled(name: String, type: StartupItemType) async -> Bool {
        do {
            let output = try await CommandExecutor.shared.execute("/bin/launchctl", arguments: ["list"])
            return output.contains(name)
        } catch {
            return false
        }
    }

    // Toggle Functions
    private func toggleLoginItem(_ item: StartupItem) {
        Task {
            // Login items toggling requires AppleScript
            let action = item.isEnabled ? "delete" : "make"
            let script = """
            tell application "System Events"
                \(action) login item "\(item.name)"
            end tell
            """

            do {
                try await CommandExecutor.shared.execute("/usr/bin/osascript", arguments: ["-e", script])
                activityLog.log("Login item '\(item.name)' \(item.isEnabled ? "disabled" : "enabled")", type: .success)
                notificationManager.showSuccess(message: "Login item updated")
                await loadLoginItems()
            } catch {
                activityLog.log("Failed to toggle login item: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func toggleLaunchAgent(_ item: StartupItem) {
        Task {
            do {
                if item.isEnabled {
                    try await CommandExecutor.shared.execute("/bin/launchctl", arguments: ["unload", item.path])
                } else {
                    try await CommandExecutor.shared.execute("/bin/launchctl", arguments: ["load", item.path])
                }
                activityLog.log("Launch agent '\(item.name)' \(item.isEnabled ? "disabled" : "enabled")", type: .success)
                notificationManager.showSuccess(message: "Launch agent updated")
                await loadLaunchAgents()
            } catch {
                activityLog.log("Failed to toggle launch agent: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func toggleLaunchDaemon(_ item: StartupItem) {
        Task {
            do {
                if item.isEnabled {
                    try await CommandExecutor.shared.execute("/bin/launchctl", arguments: ["unload", item.path], sudo: true)
                } else {
                    try await CommandExecutor.shared.execute("/bin/launchctl", arguments: ["load", item.path], sudo: true)
                }
                activityLog.log("Launch daemon '\(item.name)' \(item.isEnabled ? "disabled" : "enabled")", type: .success)
                notificationManager.showSuccess(message: "Launch daemon updated")
                await loadLaunchDaemons()
            } catch {
                activityLog.log("Failed to toggle launch daemon: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Requires administrator privileges")
            }
        }
    }

    // Remove Functions
    private func removeLoginItem(_ item: StartupItem) {
        toggleLoginItem(item)
    }

    private func removeLaunchAgent(_ item: StartupItem) {
        Task {
            do {
                // First unload if loaded
                if item.isEnabled {
                    try await CommandExecutor.shared.execute("/bin/launchctl", arguments: ["unload", item.path])
                }
                // Then delete file
                try FileManager.default.removeItem(atPath: item.path)
                activityLog.log("Launch agent '\(item.name)' removed", type: .success)
                notificationManager.showSuccess(message: "Launch agent removed")
                await loadLaunchAgents()
            } catch {
                activityLog.log("Failed to remove launch agent: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func removeLaunchDaemon(_ item: StartupItem) {
        Task {
            do {
                // First unload if loaded
                if item.isEnabled {
                    try await CommandExecutor.shared.execute("/bin/launchctl", arguments: ["unload", item.path], sudo: true)
                }
                // Then delete file
                try await CommandExecutor.shared.execute("/bin/rm", arguments: [item.path], sudo: true)
                activityLog.log("Launch daemon '\(item.name)' removed", type: .success)
                notificationManager.showSuccess(message: "Launch daemon removed")
                await loadLaunchDaemons()
            } catch {
                activityLog.log("Failed to remove launch daemon: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Requires administrator privileges")
            }
        }
    }
}

// Models
struct StartupItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    var isEnabled: Bool
    let type: StartupItemType
}

enum StartupItemType {
    case loginItem
    case launchAgent
    case launchDaemon
}

// Supporting Views
struct StartupItemsList: View {
    let items: [StartupItem]
    let title: String
    let description: String
    let onToggle: (StartupItem) -> Void
    let onRemove: (StartupItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if items.isEmpty {
                Text("No items found")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(items) { item in
                    StartupItemRow(item: item, onToggle: onToggle, onRemove: onRemove)
                }
            }
        }
    }
}

struct StartupItemRow: View {
    let item: StartupItem
    let onToggle: (StartupItem) -> Void
    let onRemove: (StartupItem) -> Void

    @State private var showingRemoveConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                if !item.path.isEmpty {
                    Text(item.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { _ in onToggle(item) }
            ))
            .labelsHidden()

            Button(action: { showingRemoveConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .alert("Remove \(item.name)?", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                onRemove(item)
            }
        } message: {
            Text("This will permanently remove this startup item.")
        }
    }
}

#Preview {
    StartupItemsView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700, height: 600)
}
