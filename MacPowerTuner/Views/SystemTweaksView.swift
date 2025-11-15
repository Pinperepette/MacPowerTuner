import SwiftUI
import UniformTypeIdentifiers

struct SystemTweaksView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var screenshotFormat = "png"
    @State private var screenshotLocation = ""
    @State private var showingFolderPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Screenshot Settings", icon: "camera") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screenshot Format")
                            .font(.body)
                        Picker("Format", selection: $screenshotFormat) {
                            Text("PNG").tag("png")
                            Text("JPG").tag("jpg")
                            Text("PDF").tag("pdf")
                            Text("TIFF").tag("tiff")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: screenshotFormat) { _ in
                            applyScreenshotFormat()
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screenshot Location")
                            .font(.body)
                        HStack {
                            Text(screenshotLocation.isEmpty ? "Default (Desktop)" : screenshotLocation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Choose Folder...") {
                                showingFolderPicker = true
                            }
                        }
                    }
                }
            }

            SectionCard(title: "Appearance", icon: "paintbrush") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Button(action: { setAppearance("Dark") }) {
                            Label("Force Dark Mode", systemImage: "moon.fill")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { setAppearance("Light") }) {
                            Label("Force Light Mode", systemImage: "sun.max.fill")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { setAppearance("Auto") }) {
                            Label("Auto", systemImage: "circle.lefthalf.filled")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            SectionCard(title: "Battery", icon: "battery.100") {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: toggleBatteryPercentage) {
                        Label("Toggle Battery Percentage", systemImage: "percent")
                    }
                    .buttonStyle(.bordered)
                    Text("Shows/hides battery percentage in menu bar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .onAppear(perform: loadCurrentSettings)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    private func loadCurrentSettings() {
        Task {
            do {
                let formatOutput = try await CommandExecutor.shared.readDefaults(domain: "com.apple.screencapture", key: "type")
                screenshotFormat = formatOutput.trimmingCharacters(in: .whitespacesAndNewlines)

                let locationOutput = try await CommandExecutor.shared.readDefaults(domain: "com.apple.screencapture", key: "location")
                screenshotLocation = locationOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                // Use defaults
                screenshotFormat = "png"
            }
        }
    }

    private func applyScreenshotFormat() {
        Task {
            do {
                try await CommandExecutor.shared.executeDefaults(
                    domain: "com.apple.screencapture",
                    key: "type",
                    value: screenshotFormat
                )
                try await CommandExecutor.shared.killProcess(name: "SystemUIServer")
                activityLog.log("Screenshot format set to \(screenshotFormat.uppercased())", type: .success)
                notificationManager.showSuccess(message: "Screenshot format updated")
            } catch {
                activityLog.log("Failed to set screenshot format: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            screenshotLocation = url.path
            Task {
                do {
                    try await CommandExecutor.shared.executeDefaults(
                        domain: "com.apple.screencapture",
                        key: "location",
                        value: url.path
                    )
                    try await CommandExecutor.shared.killProcess(name: "SystemUIServer")
                    activityLog.log("Screenshot location set to \(url.path)", type: .success)
                    notificationManager.showSuccess(message: "Screenshot location updated")
                } catch {
                    activityLog.log("Failed to set screenshot location: \(error.localizedDescription)", type: .error)
                    notificationManager.showError(message: error.localizedDescription)
                }
            }
        case .failure(let error):
            activityLog.log("Failed to select folder: \(error.localizedDescription)", type: .error)
        }
    }

    private func setAppearance(_ mode: String) {
        Task {
            do {
                let value: String
                switch mode {
                case "Dark":
                    value = "true"
                case "Light":
                    value = "false"
                default: // Auto
                    // Delete the key to restore auto mode
                    try await CommandExecutor.shared.execute("/usr/bin/defaults", arguments: ["delete", "NSGlobalDomain", "AppleInterfaceStyle"])
                    activityLog.log("Appearance set to Auto", type: .success)
                    notificationManager.showSuccess(message: "Appearance updated to Auto")
                    return
                }

                try await CommandExecutor.shared.execute("/usr/bin/defaults", arguments: ["write", "NSGlobalDomain", "AppleInterfaceStyle", mode])
                activityLog.log("Appearance set to \(mode) Mode", type: .success)
                notificationManager.showSuccess(message: "Appearance updated to \(mode) Mode")
            } catch {
                activityLog.log("Failed to set appearance: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }

    private func toggleBatteryPercentage() {
        Task {
            do {
                // This uses a shell command to toggle the menu bar battery percentage
                let script = """
                osascript -e 'tell application "System Settings"
                    activate
                end tell'
                """
                try await CommandExecutor.shared.execute("/bin/sh", arguments: ["-c", script])
                activityLog.log("Opening System Settings to toggle battery percentage", type: .info)
                notificationManager.showSuccess(message: "Please toggle battery percentage in Control Center settings")
            } catch {
                activityLog.log("Failed to open System Settings: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: error.localizedDescription)
            }
        }
    }
}

#Preview {
    SystemTweaksView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
