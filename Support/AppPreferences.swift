import Foundation

enum AppPreferences {
    static let autoRefreshEnabledKey = "ScrutinyMonitor.autoRefreshEnabled"
    static let autoRefreshIntervalKey = "ScrutinyMonitor.autoRefreshInterval"
    static let defaultAutoRefreshInterval = 300.0
    static let driveFailureNotificationsEnabledKey = "ScrutinyMonitor.driveFailureNotificationsEnabled"
    static let desktopNotificationsEnabledKey = "ScrutinyMonitor.desktopNotificationsEnabled"
    static let showMenuBarExtraKey = "ScrutinyMonitor.showMenuBarExtra"

    static let refreshIntervals: [RefreshIntervalOption] = [
        RefreshIntervalOption(title: "Every 1 minute", seconds: 60),
        RefreshIntervalOption(title: "Every 5 minutes", seconds: 300),
        RefreshIntervalOption(title: "Every 15 minutes", seconds: 900),
        RefreshIntervalOption(title: "Every 30 minutes", seconds: 1_800),
        RefreshIntervalOption(title: "Every 1 hour", seconds: 3_600)
    ]
}

struct RefreshIntervalOption: Identifiable, Hashable {
    var title: String
    var seconds: Double

    var id: Double {
        seconds
    }
}
