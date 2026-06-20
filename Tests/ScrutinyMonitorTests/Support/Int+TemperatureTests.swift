import XCTest
import SwiftUI
@testable import ScrutinyMonitor

final class IntTemperatureTests: XCTestCase {
    func testTemperatureColorGreen() {
        XCTAssertEqual(0.temperatureColor, .green)
        XCTAssertEqual(39.temperatureColor, .green)
        XCTAssertEqual((-10).temperatureColor, .green)
    }

    func testTemperatureColorOrange() {
        XCTAssertEqual(40.temperatureColor, .orange)
        XCTAssertEqual(45.temperatureColor, .orange)
        XCTAssertEqual(49.temperatureColor, .orange)
    }

    func testTemperatureColorRed() {
        XCTAssertEqual(50.temperatureColor, .red)
        XCTAssertEqual(55.temperatureColor, .red)
        XCTAssertEqual(100.temperatureColor, .red)
    }

    func testTemperatureColor() {
        XCTAssertEqual(50.temperatureColor, Color.red)
        XCTAssertEqual(55.temperatureColor, Color.red)

        XCTAssertEqual(40.temperatureColor, Color.orange)
        XCTAssertEqual(45.temperatureColor, Color.orange)
        XCTAssertEqual(49.temperatureColor, Color.orange)

        XCTAssertEqual(39.temperatureColor, Color.green)
        XCTAssertEqual(0.temperatureColor, Color.green)
        XCTAssertEqual((-10).temperatureColor, Color.green)
    }
}
