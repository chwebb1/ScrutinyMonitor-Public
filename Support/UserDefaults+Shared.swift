import Foundation

extension UserDefaults {
    static let appGroupIdentifier =
        Bundle.main.object(forInfoDictionaryKey: "ScrutinyMonitorAppGroupIdentifier") as? String
        ?? "group.com.chriswebb.ScrutinyMonitor"

    public static let shared = UserDefaults(suiteName: appGroupIdentifier) ?? .standard

    public static var ephemeral: UserDefaults {
        let suiteName = "com.scrutinymonitor.tests.ephemeral"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
