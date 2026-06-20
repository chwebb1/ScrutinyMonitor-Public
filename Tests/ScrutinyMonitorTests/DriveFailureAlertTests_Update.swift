import XCTest
@testable import ScrutinyMonitor

final class DriveFailureAlertTests_Update: XCTestCase {

    func testAlertIdAndTitle() {
        let drive = DriveSnapshot(
            id: "drive-1",
            name: "Test Drive",
            model: "Model",
            serial: "123",
            protocolName: "NVMe",
            capacityBytes: 1000,
            statusCode: 1, // warning
            temperature: 40,
            powerOnHours: 10,
            collectorDate: "date"
        )

        let alert = DriveFailureAlert(installationName: "Server", drive: drive, previousStatus: .passed)

        XCTAssertEqual(alert.id, "Server-drive-1-warning")
        XCTAssertEqual(alert.title, "Drive Warning")
    }

    func testAlertMessageNameEmpty() {
        let drive = DriveSnapshot(
            id: "drive-1",
            name: "",
            model: "Model",
            serial: "12345",
            protocolName: "NVMe",
            capacityBytes: 1000,
            statusCode: 2, // failed
            temperature: 40,
            powerOnHours: 10,
            collectorDate: "date"
        )

        let alert = DriveFailureAlert(installationName: "Server", drive: drive, previousStatus: .passed)
        XCTAssertEqual(alert.title, "Drive Failure")
        XCTAssertEqual(alert.message, "12345 on Server is now failed.")
    }

    func testAlertMessageNameAndSerialEmpty() {
        let drive = DriveSnapshot(
            id: "drive-1",
            name: "",
            model: "Model",
            serial: "",
            protocolName: "NVMe",
            capacityBytes: 1000,
            statusCode: 2, // failed
            temperature: 40,
            powerOnHours: 10,
            collectorDate: "date"
        )

        let alert = DriveFailureAlert(installationName: "Server", drive: drive, previousStatus: .passed)
        XCTAssertEqual(alert.title, "Drive Failure")
        XCTAssertEqual(alert.message, "drive-1 on Server is now failed.")
    }

    func testDriveStatusIsAtRisk() {
        XCTAssertTrue(DriveStatus.warning.isAtRisk)
        XCTAssertTrue(DriveStatus.failed.isAtRisk)
        XCTAssertFalse(DriveStatus.passed.isAtRisk)
        XCTAssertFalse(DriveStatus.unknown.isAtRisk)
    }
}
