import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case systemInfo = "System Info"
    case finder = "Finder & File System"
    case dock = "Dock & Mission Control"
    case systemTweaks = "System & UI Tweaks"
    case privacy = "Privacy & Security"
    case network = "Network Tools"
    case hardware = "Hardware & Performance"
    case startupItems = "Startup Items"
    case appUninstaller = "App Uninstaller"
    case diskUsage = "Disk Usage"
    case scripts = "Script Manager"
    case maintenance = "Maintenance & Cleanup"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge"
        case .systemInfo: return "info.circle"
        case .finder: return "folder"
        case .dock: return "dock.rectangle"
        case .systemTweaks: return "gearshape.2"
        case .privacy: return "lock.shield"
        case .network: return "network"
        case .hardware: return "cpu"
        case .startupItems: return "power"
        case .appUninstaller: return "trash"
        case .diskUsage: return "internaldrive"
        case .scripts: return "terminal"
        case .maintenance: return "wrench.and.screwdriver"
        case .about: return "info.circle.fill"
        }
    }
}
