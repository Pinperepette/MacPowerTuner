import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .dashboard
    @State private var showActivityLog = false
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showActivityLog.toggle() }) {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .help("Activity Log")
                }
            }
        } detail: {
            // Detail view
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: selectedItem.icon)
                        .font(.title)
                        .foregroundColor(.accentColor)
                    Text(selectedItem.rawValue)
                        .font(.title)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Content
                if selectedItem == .appUninstaller {
                    getDetailView(for: selectedItem)
                } else {
                    ScrollView {
                        getDetailView(for: selectedItem)
                            .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showActivityLog) {
            ActivityLogView()
                .environmentObject(activityLog)
                .frame(minWidth: 600, minHeight: 400)
        }
        .alert(notificationManager.alertTitle, isPresented: $notificationManager.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notificationManager.alertMessage)
        }
    }

    @ViewBuilder
    private func getDetailView(for item: SidebarItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .systemInfo:
            SystemInfoView()
        case .finder:
            FinderView()
        case .dock:
            DockView()
        case .systemTweaks:
            SystemTweaksView()
        case .privacy:
            PrivacySecurityView()
        case .network:
            NetworkToolsView()
        case .hardware:
            HardwarePerformanceView()
        case .startupItems:
            StartupItemsView()
        case .appUninstaller:
            AppUninstallerView()
        case .diskUsage:
            DiskUsageView()
        case .scripts:
            ScriptManagerView()
        case .maintenance:
            MaintenanceView()
        case .about:
            AboutView()
        }
    }
}

struct ActivityLogView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity Log")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Clear") {
                    activityLog.clear()
                }
                Button("Close") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Log entries
            if activityLog.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No activity yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(activityLog.entries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: iconForType(entry.type))
                            .foregroundColor(colorForType(entry.type))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.message)
                                .font(.system(.body, design: .monospaced))
                            Text(entry.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func iconForType(_ type: LogEntry.LogType) -> String {
        switch type {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private func colorForType(_ type: LogEntry.LogType) -> Color {
        switch type {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
}
