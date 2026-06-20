import XCTest
import SwiftUI
@testable import ScrutinyMonitor

final class DriveStatusTests: XCTestCase {
    func testInitialization() {
        XCTAssertEqual(DriveStatus(statusCode: 0), .passed)
        XCTAssertEqual(DriveStatus(statusCode: 1), .warning)
        XCTAssertEqual(DriveStatus(statusCode: 2), .failed)
        XCTAssertEqual(DriveStatus(statusCode: -1), .failed)
        XCTAssertEqual(DriveStatus(statusCode: nil), .unknown)
    }

    func testPropertiesForPassed() {
        let status = DriveStatus.passed
        XCTAssertEqual(status.label, "Passed")
        XCTAssertEqual(status.symbolName, "checkmark.circle")
        XCTAssertEqual(status.color, .green)
        XCTAssertEqual(status.sortRank, 3)
    }

    func testPropertiesForWarning() {
        let status = DriveStatus.warning
        XCTAssertEqual(status.label, "Warning")
        XCTAssertEqual(status.symbolName, "exclamationmark.triangle")
        XCTAssertEqual(status.color, .yellow)
        XCTAssertEqual(status.sortRank, 1)
    }

    func testPropertiesForFailed() {
        let status = DriveStatus.failed
        XCTAssertEqual(status.label, "Failed")
        XCTAssertEqual(status.symbolName, "xmark.octagon")
        XCTAssertEqual(status.color, .red)
        XCTAssertEqual(status.sortRank, 0)
    }

    func testPropertiesForUnknown() {
        let status = DriveStatus.unknown
        XCTAssertEqual(status.label, "Unknown")
        XCTAssertEqual(status.symbolName, "questionmark.circle")
        XCTAssertEqual(status.color, .secondary)
        XCTAssertEqual(status.sortRank, 2)
    }
}
