import SwiftUI

struct DiskUsageView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var diskInfo: DiskInfo?
    @State private var largeFiles: [FileItem] = []
    @State private var folderSizes: [FolderSize] = []
    @State private var isScanning = false
    @State private var isLoadingFolders = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disk overview
            if let disk = diskInfo {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Disk Usage")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()

                        Button(action: loadDiskInfo) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                    }

                    // Usage bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Used: \(disk.used)")
                                .font(.caption)
                            Spacer()
                            Text("Free: \(disk.available)")
                                .font(.caption)
                            Spacer()
                            Text("Total: \(disk.total)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))

                                Rectangle()
                                    .fill(disk.usagePercent > 90 ? Color.red : disk.usagePercent > 70 ? Color.orange : Color.blue)
                                    .frame(width: geometry.size.width * (disk.usagePercent / 100))
                            }
                            .cornerRadius(4)
                        }
                        .frame(height: 24)

                        Text("\(Int(disk.usagePercent))% Used")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }

            Divider()

            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Large Files").tag(0)
                Text("Folder Sizes").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content
            if selectedTab == 0 {
                // Large Files
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Large Files (> 100 MB)")
                            .font(.headline)

                        Spacer()

                        if isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: scanForLargeFiles) {
                                Label("Scan for Large Files", systemImage: "doc.text.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    if largeFiles.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Click 'Scan for Large Files' to find files larger than 100 MB")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(largeFiles) { file in
                            LargeFileRow(file: file, onReveal: revealInFinder, onDelete: deleteFile)
                        }
                    }
                }
            } else {
                // Folder Sizes
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Folder Sizes")
                            .font(.headline)

                        Spacer()

                        if isLoadingFolders {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Calculating...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: analyzeFolders) {
                                Label("Analyze Folders", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    if folderSizes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "folder")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Click 'Analyze Folders' to see folder sizes in your home directory")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(folderSizes) { folder in
                            FolderSizeRow(folder: folder, onReveal: revealInFinder)
                        }
                    }
                }
            }
        }
        .onAppear {
            if diskInfo == nil {
                loadDiskInfo()
            }
        }
    }

    private func loadDiskInfo() {
        Task {
            do {
                let output = try await CommandExecutor.shared.execute("/bin/df", arguments: ["-h", "/"])
                let lines = output.split(separator: "\n")

                if lines.count > 1 {
                    let components = lines[1].split(separator: " ").filter { !$0.isEmpty }
                    if components.count >= 5 {
                        let total = String(components[1])
                        let used = String(components[2])
                        let available = String(components[3])
                        let percentStr = String(components[4]).replacingOccurrences(of: "%", with: "")
                        let percent = Double(percentStr) ?? 0

                        DispatchQueue.main.async {
                            self.diskInfo = DiskInfo(
                                total: total,
                                used: used,
                                available: available,
                                usagePercent: percent
                            )
                        }
                    }
                }
            } catch {
                activityLog.log("Failed to load disk info: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func scanForLargeFiles() {
        isScanning = true
        largeFiles = []

        Task {
            do {
                // Scan home directory for large files
                let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                let output = try await CommandExecutor.shared.execute("/usr/bin/find", arguments: [homeDir, "-type", "f", "-size", "+100M"])

                var files: [FileItem] = []
                let filePaths = output.split(separator: "\n").map { String($0) }

                for filePath in filePaths.prefix(100) { // Limit to 100 files
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
                       let fileSize = attributes[.size] as? Int64 {
                        files.append(FileItem(
                            path: filePath,
                            size: formatBytes(fileSize),
                            sizeBytes: fileSize
                        ))
                    }
                }

                DispatchQueue.main.async {
                    self.largeFiles = files.sorted { $0.sizeBytes > $1.sizeBytes }
                    self.isScanning = false
                }

                activityLog.log("Found \(files.count) large files", type: .info)
            } catch {
                DispatchQueue.main.async {
                    self.isScanning = false
                }
                activityLog.log("Failed to scan for large files: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func analyzeFolders() {
        isLoadingFolders = true
        folderSizes = []

        Task {
            var folders: [FolderSize] = []
            let homeDir = FileManager.default.homeDirectoryForCurrentUser

            let commonFolders = [
                "Desktop",
                "Documents",
                "Downloads",
                "Pictures",
                "Movies",
                "Music",
                "Library",
                "Applications"
            ]

            for folder in commonFolders {
                let folderPath = homeDir.appendingPathComponent(folder)

                if FileManager.default.fileExists(atPath: folderPath.path) {
                    let size = calculateFolderSize(at: folderPath)
                    folders.append(FolderSize(
                        name: folder,
                        path: folderPath.path,
                        size: formatBytes(size),
                        sizeBytes: size
                    ))
                }
            }

            DispatchQueue.main.async {
                self.folderSizes = folders.sorted { $0.sizeBytes > $1.sizeBytes }
                self.isLoadingFolders = false
            }

            activityLog.log("Analyzed \(folders.count) folders", type: .info)
        }
    }

    private func calculateFolderSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    private func deleteFile(_ file: FileItem) {
        Task {
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                activityLog.log("File moved to Trash: \(file.path)", type: .success)
                notificationManager.showSuccess(message: "File moved to Trash")

                // Refresh list
                DispatchQueue.main.async {
                    largeFiles.removeAll { $0.id == file.id }
                }
            } catch {
                activityLog.log("Failed to delete file: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }
}

// Models
struct DiskInfo {
    let total: String
    let used: String
    let available: String
    let usagePercent: Double
}

struct FileItem: Identifiable {
    let id = UUID()
    let path: String
    let size: String
    let sizeBytes: Int64
}

struct FolderSize: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: String
    let sizeBytes: Int64
}

// Supporting Views
struct LargeFileRow: View {
    let file: FileItem
    let onReveal: (String) -> Void
    let onDelete: (FileItem) -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: file.path).lastPathComponent)
                    .font(.body)
                Text(file.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(file.size)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            Button(action: { onReveal(file.path) }) {
                Image(systemName: "arrow.right.circle")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")

            Button(action: { showingDeleteConfirmation = true }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
            .help("Move to Trash")
        }
        .padding(.vertical, 4)
        .alert("Delete file?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                onDelete(file)
            }
        } message: {
            Text("This will move the file to Trash.")
        }
    }
}

struct FolderSizeRow: View {
    let folder: FolderSize
    let onReveal: (String) -> Void

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)

            Text(folder.name)
                .font(.body)

            Spacer()

            Text(folder.size)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            Button(action: { onReveal(folder.path) }) {
                Image(systemName: "arrow.right.circle")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DiskUsageView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 800, height: 600)
}
