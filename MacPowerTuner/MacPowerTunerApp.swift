import SwiftUI

@main
struct MacPowerTunerApp: App {
    @StateObject private var activityLog = ActivityLog()
    @StateObject private var notificationManager = NotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activityLog)
                .environmentObject(notificationManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
