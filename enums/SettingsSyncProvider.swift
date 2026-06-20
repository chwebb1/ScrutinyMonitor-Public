import Foundation

public enum SettingsSyncProvider: String, CaseIterable, Identifiable {
    case iCloud
    case selectFolder
    case webDAV

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .iCloud:
            "iCloud"
        case .selectFolder:
            "Select a folder"
        case .webDAV:
            "WebDAV"
        }
    }

    public var symbolName: String {
        switch self {
        case .iCloud:
            "icloud.fill"
        case .selectFolder:
            "folder.fill"
        case .webDAV:
            "network"
        }
    }

    public var usesFolder: Bool {
        switch self {
        case .selectFolder:
            true
        case .iCloud, .webDAV:
            false
        }
    }
}
