import XCTest
@testable import ScrutinyMonitor

final class DriveFailureAlertTests: XCTestCase {
    func testNewlyAtRiskDrivesIncludesWarningTransitions() {
        let previous = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 0)
        ])
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 1)
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: previous,
            current: current
        )

        XCTAssertEqual(alerts.map(\.drive.id), ["disk-1"])
    }

    func testNewlyAtRiskDrivesDoesNotRepeatExistingWarning() {
        let previous = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 1)
        ])
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 1)
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: previous,
            current: current
        )

        XCTAssertTrue(alerts.isEmpty)
    }

    func testNewlyAtRiskDrivesIncludesNewFailedDriveWithoutPreviousSnapshot() {
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 2)
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: nil,
            current: current
        )

        XCTAssertEqual(alerts.map(\.drive.status), [.failed])
    }

    func testNewlyAtRiskDrivesIncludesNewFailedDriveWithEmptyPreviousSnapshot() {
        let previous = makeSnapshot(devices: [])
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 2)
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: previous,
            current: current
        )

        XCTAssertEqual(alerts.map(\.drive.status), [.failed])
    }

    func testNewlyAtRiskDrivesIncludesFailedTransitions() {
        let previous = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 0) // Passed
        ])
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 2) // Failed
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: previous,
            current: current
        )

        XCTAssertEqual(alerts.map(\.drive.id), ["disk-1"])
        XCTAssertEqual(alerts.map(\.drive.status), [.failed])
    }

    func testNewlyAtRiskDrivesIgnoresHealthyDrives() {
        let previous = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 0), // Passed
            makeDrive(id: "disk-2", statusCode: 1)  // Warning
        ])
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 0), // Passed -> Passed
            makeDrive(id: "disk-2", statusCode: 0)  // Warning -> Passed
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: previous,
            current: current
        )

        XCTAssertTrue(alerts.isEmpty)
    }

    func testNewlyAtRiskDrivesIgnoresAtRiskToAtRisk() {
        let previous = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 1), // Warning
            makeDrive(id: "disk-2", statusCode: 2)  // Failed
        ])
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 2), // Warning -> Failed
            makeDrive(id: "disk-2", statusCode: 1)  // Failed -> Warning
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: previous,
            current: current
        )

        XCTAssertTrue(alerts.isEmpty) // Alerts shouldn't trigger for drives already at risk
    }

    func testNewlyAtRiskDrivesHandlesUnknownToAtRisk() {
        let previous = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: nil) // Unknown
        ])
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 1) // Unknown -> Warning
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: previous,
            current: current
        )

        XCTAssertEqual(alerts.map(\.drive.id), ["disk-1"])
    }

    func testNewlyAtRiskDrivesHandlesMultipleDrives() {
        let previous = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 0), // Passed
            makeDrive(id: "disk-2", statusCode: 1), // Warning
            makeDrive(id: "disk-3", statusCode: 0), // Passed
            makeDrive(id: "disk-4", statusCode: 2)  // Failed
        ])
        let current = makeSnapshot(devices: [
            makeDrive(id: "disk-1", statusCode: 1), // Passed -> Warning (Alert)
            makeDrive(id: "disk-2", statusCode: 0), // Warning -> Passed (No Alert)
            makeDrive(id: "disk-3", statusCode: 2), // Passed -> Failed (Alert)
            makeDrive(id: "disk-4", statusCode: 1)  // Failed -> Warning (No Alert, already at risk)
        ])

        let alerts = DriveFailureAlert.newlyAtRiskDrives(
            installationName: "NAS",
            previous: previous,
            current: current
        )

        XCTAssertEqual(alerts.count, 2)
        XCTAssertEqual(alerts.map(\.drive.id).sorted(), ["disk-1", "disk-3"])
    }

    private func makeSnapshot(devices: [DriveSnapshot]) -> InstallationSnapshot {
        InstallationSnapshot(
            healthOK: true,
            totalDrives: devices.count,
            healthyDrives: devices.filter { $0.status == .passed }.count,
            warningDrives: devices.filter { $0.status == .warning }.count,
            criticalDrives: devices.filter { $0.status == .failed }.count,
            devices: devices,
            collectedAt: Date()
        )
    }

    private func makeDrive(id: String, statusCode: Int?) -> DriveSnapshot {
        DriveSnapshot(
            id: id,
            name: "Drive \(id)",
            model: "Model",
            serial: "Serial",
            protocolName: "sat",
            capacityBytes: nil,
            statusCode: statusCode,
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )
    }
}
