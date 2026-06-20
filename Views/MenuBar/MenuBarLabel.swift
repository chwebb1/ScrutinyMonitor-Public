import SwiftUI

struct MenuBarLabel: View {
    let store: MonitorStore

    var body: some View {
        let status = store.overallStatus
        Image(systemName: labelSymbolName(for: status))
            .symbolRenderingMode(.multicolor)
    }

    private func labelSymbolName(for status: InstallationStatus) -> String {
        switch status {
        case .healthy:
            return "externaldrive"
        case .warning:
            return "externaldrive.badge.exclamationmark"
        case .critical:
            return "externaldrive.badge.xmark"
        case .offline:
            return "wifi.slash"
        case .refreshing:
            return "arrow.clockwise"
        case .empty:
            return "externaldrive"
        case .unknown:
            return "externaldrive"
        }
    }
}
