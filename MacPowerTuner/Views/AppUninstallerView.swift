import SwiftUI

struct AppUninstallerView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var apps: [InstalledApp] = []
    @State private var selectedApp: InstalledApp?
    @State private var relatedFiles: [RelatedFile] = []
    @State private var isLoading = true
    @State private var isScanning = false
    @State private var showingUninstallConfirmation = false
    @State private var searchText = ""

    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left side - App List
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search apps...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .padding()

                // App list
                if isLoading && apps.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Scanning applications...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredApps) { app in
                                Button(action: { selectedApp = app }) {
                                    AppListRow(app: app)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(selectedApp?.id == app.id ? Color.accentColor.opacity(0.2) : Color.clear)

                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
            }
            .frame(width: 350)
            .clipped()

            Divider()

            // Right side - App Details
            if let app = selectedApp {
                VStack(alignment: .leading, spacing: 0) {
                    // App header
                    HStack(spacing: 16) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 64, height: 64)
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(app.version)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(app.size)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { showingUninstallConfirmation = true }) {
                            Label("Uninstall", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    // Related files
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Related Files")
                                    .font(.headline)

                                Spacer()

                                if isScanning {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Button(action: { scanForRelatedFiles(app: app) }) {
                                        Label("Scan for Files", systemImage: "doc.text.magnifyingglass")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            if relatedFiles.isEmpty {
                                Text("Click 'Scan for Files' to find related files, caches, preferences, and support files.")
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(relatedFiles) { file in
                                    RelatedFileRow(file: file)
                                }

                                Text("Total size: \(formatTotalSize())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Select an app to view details")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if isLoading {
                loadInstalledApps()
            }
        }
        .alert("Uninstall \(selectedApp?.name ?? "App")?", isPresented: $showingUninstallConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive) {
                if let app = selectedApp {
                    uninstallApp(app)
                }
            }
        } message: {
            Text("This will move the app and all related files to Trash. This action cannot be undone.")
        }
    }

    private func loadInstalledApps() {
        isLoading = true

        Task {
            let applicationFolders = [
                "/Applications",
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
            ]

            // First pass: load apps quickly without size calculation
            for folder in applicationFolders {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: folder)

                    for item in contents where item.hasSuffix(".app") {
                        let fullPath = (folder as NSString).appendingPathComponent(item)
                        let url = URL(fileURLWithPath: fullPath)

                        let name = (item as NSString).deletingPathExtension
                        let version = getAppVersion(at: url) ?? "Unknown"
                        let icon = NSWorkspace.shared.icon(forFile: fullPath)

                        let app = InstalledApp(
                            name: name,
                            path: fullPath,
                            version: version,
                            size: "Calculating...",
                            icon: icon
                        )

                        // Add app immediately to UI (skip if already exists)
                        await MainActor.run {
                            if !self.apps.contains(where: { $0.name == name }) {
                                self.apps.append(app)
                                self.apps.sort { $0.name < $1.name }
                            }
                        }

                        // Calculate size asynchronously in background
                        Task.detached(priority: .background) {
                            let size = await self.calculateDirectorySize(at: url)

                            await MainActor.run {
                                if let index = self.apps.firstIndex(where: { $0.id == app.id }) {
                                    self.apps[index] = InstalledApp(
                                        name: app.name,
                                        path: app.path,
                                        version: app.version,
                                        size: size,
                                        icon: app.icon
                                    )
                                }
                            }
                        }
                    }
                } catch {
                    print("Failed to read \(folder): \(error)")
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func getAppVersion(at url: URL) -> String? {
        let infoPath = url.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPath),
              let version = plist["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
    }

    private func calculateDirectorySize(at url: URL) async -> String {
        return await Task.detached(priority: .utility) {
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else {
                return "Unknown"
            }

            var totalSize: Int64 = 0

            for case let fileURL as URL in enumerator {
                // Skip certain directories to speed up calculation
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                   resourceValues.isDirectory == false,
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }

            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSize)
        }.value
    }

    private func getDirectorySize(at url: URL) -> String {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "Unknown"
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return formatBytes(totalSize)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func scanForRelatedFiles(app: InstalledApp) {
        isScanning = true
        relatedFiles = []

        Task {
            var files: [RelatedFile] = []

            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let searchPaths = [
                homeDir.appendingPathComponent("Library/Preferences"),
                homeDir.appendingPathComponent("Library/Application Support"),
                homeDir.appendingPathComponent("Library/Caches"),
                homeDir.appendingPathComponent("Library/Logs"),
                homeDir.appendingPathComponent("Library/Saved Application State"),
                URL(fileURLWithPath: "/Library/Application Support"),
                URL(fileURLWithPath: "/Library/Preferences"),
                URL(fileURLWithPath: "/Library/Caches")
            ]

            let appName = app.name
            let bundleIdentifier = getAppBundleIdentifier(at: app.path)

            for searchPath in searchPaths {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: searchPath, includingPropertiesForKeys: [.fileSizeKey])

                    for url in contents {
                        let fileName = url.lastPathComponent

                        // Check if file is related to app
                        if fileName.localizedCaseInsensitiveContains(appName) ||
                           (bundleIdentifier != nil && fileName.contains(bundleIdentifier!)) {

                            let size = getFileSize(at: url)
                            let category = categorizeFile(path: searchPath.path)

                            files.append(RelatedFile(
                                path: url.path,
                                size: size,
                                category: category
                            ))
                        }
                    }
                } catch {
                    // Ignore errors for inaccessible directories
                }
            }

            DispatchQueue.main.async {
                self.relatedFiles = files.sorted { $0.path < $1.path }
                self.isScanning = false
            }
        }
    }

    private func getAppBundleIdentifier(at path: String) -> String? {
        let infoPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: URL(fileURLWithPath: infoPath)),
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            return nil
        }
        return bundleID
    }

    private func getFileSize(at url: URL) -> String {
        if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) {
            if resourceValues.isDirectory == true {
                return getDirectorySize(at: url)
            } else if let fileSize = resourceValues.fileSize {
                return formatBytes(Int64(fileSize))
            }
        }
        return "Unknown"
    }

    private func categorizeFile(path: String) -> String {
        if path.contains("Preferences") {
            return "Preferences"
        } else if path.contains("Application Support") {
            return "Support Files"
        } else if path.contains("Caches") {
            return "Cache"
        } else if path.contains("Logs") {
            return "Logs"
        } else if path.contains("Saved Application State") {
            return "App State"
        }
        return "Other"
    }

    private func formatTotalSize() -> String {
        let total = relatedFiles.reduce(0) { result, file in
            // Extract number from size string (rough approximation)
            return result + 1024 // Placeholder
        }
        return formatBytes(Int64(total))
    }

    private func uninstallApp(_ app: InstalledApp) {
        Task {
            do {
                // Move app to trash
                try FileManager.default.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)

                // Move related files to trash
                for file in relatedFiles {
                    try? FileManager.default.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                }

                activityLog.log("App '\(app.name)' and \(relatedFiles.count) related files moved to Trash", type: .success)
                notificationManager.showSuccess(message: "App uninstalled successfully")

                // Reload apps
                loadInstalledApps()
                selectedApp = nil
                relatedFiles = []
            } catch {
                activityLog.log("Failed to uninstall app: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }
}

// Models
struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let version: String
    let size: String
    let icon: NSImage?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

struct RelatedFile: Identifiable {
    let id = UUID()
    let path: String
    let size: String
    let category: String
}

// Supporting Views
struct AppListRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                HStack(spacing: 4) {
                    if app.size == "Calculating..." {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                    }
                    Text(app.size)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RelatedFileRow: View {
    let file: RelatedFile

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.path)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack {
                    Text(file.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)

                    Text(file.size)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    AppUninstallerView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 900, height: 600)
}
