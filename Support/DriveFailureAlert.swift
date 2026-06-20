import Foundation

struct DriveFailureAlert: Identifiable, Hashable {
    var installationName: String
    var drive: DriveSnapshot
    var previousStatus: DriveStatus?

    var id: String {
        "\(installationName)-\(drive.id)-\(drive.status.rawValue)"
    }

    var title: String {
        switch drive.status {
        case .warning:
            "Drive Warning"
        case .failed:
            "Drive Failure"
        case .passed, .unknown:
            "Drive Status Changed"
        }
    }

    var message: String {
        let driveName = drive.name.isEmpty ? drive.serial : drive.name
        let displayName = driveName.isEmpty ? drive.id : driveName
        return "\(displayName) on \(installationName) is now \(drive.status.label.lowercased())."
    }

    static func newlyAtRiskDrives(
        installationName: String,
        previous: InstallationSnapshot?,
        current: InstallationSnapshot
    ) -> [DriveFailureAlert] {
        // ⚡ Bolt: Use an imperative loop with pre-allocated capacity instead of reduce(into:).
        // This avoids closure allocation overhead and the potential performance hit of repeated closure calls.
        var previousStatuses = [String: DriveStatus]()
        if let previous = previous {
            previousStatuses.reserveCapacity(previous.devices.count)
            for device in previous.devices {
                previousStatuses[device.id] = device.status
            }
        }

        var alerts = [DriveFailureAlert]()
        for drive in current.devices {
            guard drive.status.isAtRisk else { continue }
            let previousStatus = previousStatuses[drive.id]
            guard previousStatus?.isAtRisk != true else { continue }

            alerts.append(DriveFailureAlert(
                installationName: installationName,
                drive: drive,
                previousStatus: previousStatus
            ))
        }

        return alerts
    }
}

extension DriveStatus {
    var isAtRisk: Bool {
        self == .warning || self == .failed
    }
}
