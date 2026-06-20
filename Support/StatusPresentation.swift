import SwiftUI

extension InstallationStatus {
    var symbolName: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .offline: "wifi.slash"
        case .refreshing: "arrow.clockwise"
        case .empty: "tray"
        case .unknown: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .healthy: .green
        case .warning: .yellow
        case .critical, .offline: .red
        case .refreshing: .blue
        case .empty, .unknown: .secondary
        }
    }

    var statusSymbolName: String {
        switch self {
        case .healthy: "externaldrive"
        case .warning: "externaldrive.badge.exclamationmark"
        case .critical: "externaldrive.badge.xmark"
        case .offline: "wifi.slash"
        case .refreshing: "arrow.clockwise"
        case .empty: "externaldrive"
        case .unknown: "externaldrive"
        }
    }
}

extension DriveStatus {
    public var symbolName: String {
        switch self {
        case .passed: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .failed: "xmark.octagon"
        case .unknown: "questionmark.circle"
        }
    }

    public var color: Color {
        switch self {
        case .passed: .green
        case .warning: .yellow
        case .failed: .red
        case .unknown: .secondary
        }
    }
}
