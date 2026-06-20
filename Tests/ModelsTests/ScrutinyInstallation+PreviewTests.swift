import XCTest
@testable import ScrutinyMonitor

final class ScrutinyInstallationPreviewTests: XCTestCase {

    func testPreviewInstallations() {
        let installations = ScrutinyInstallation.previewInstallations

        XCTAssertEqual(installations.count, 2, "There should be exactly 2 preview installations.")

        // Test first installation
        let first = installations[0]
        XCTAssertEqual(first.name, "Home NAS")
        XCTAssertEqual(first.baseURL.absoluteString, "http://192.168.1.100")

        XCTAssertNotNil(first.lastSnapshot)
        let snap1 = first.lastSnapshot!
        XCTAssertTrue(snap1.healthOK)
        XCTAssertEqual(snap1.totalDrives, 2)
        XCTAssertEqual(snap1.healthyDrives, 2)
        XCTAssertEqual(snap1.warningDrives, 0)
        XCTAssertEqual(snap1.criticalDrives, 0)
        XCTAssertEqual(snap1.devices.count, 2)
        XCTAssertEqual(snap1.status, .healthy)
        XCTAssertEqual(first.status, .healthy)

        // Test devices in first installation
        let dev1 = snap1.devices[0]
        XCTAssertEqual(dev1.name, "sda")
        XCTAssertEqual(dev1.capacityBytes, 4000000000000)

        // Test second installation
        let second = installations[1]
        XCTAssertEqual(second.name, "Backup Server")
        XCTAssertEqual(second.baseURL.absoluteString, "http://192.168.1.200")

        XCTAssertNotNil(second.lastSnapshot)
        let snap2 = second.lastSnapshot!
        XCTAssertFalse(snap2.healthOK)
        XCTAssertEqual(snap2.totalDrives, 1)
        XCTAssertEqual(snap2.healthyDrives, 0)
        XCTAssertEqual(snap2.warningDrives, 1)
        XCTAssertEqual(snap2.criticalDrives, 0)
        XCTAssertEqual(snap2.devices.count, 1)
        XCTAssertEqual(snap2.status, .offline)
        XCTAssertEqual(second.status, .offline)

        // Test devices in second installation
        let dev3 = snap2.devices[0]
        XCTAssertEqual(dev3.name, "sdc")
        XCTAssertEqual(dev3.capacityBytes, 8000000000000)
    }
}
