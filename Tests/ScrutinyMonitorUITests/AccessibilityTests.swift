import XCTest
import SwiftUI
import ViewInspector
@testable import ScrutinyMonitor

extension MetricTile: Inspectable {}

final class AccessibilityTests: XCTestCase {
    func testMetricTileAccessibility() throws {
        let view = MetricTile(title: "Temperature", value: "35°C", symbol: "thermometer")
        let inspected = try view.inspect()
        
        let vStack = try inspected.vStack()
        
        let label = try vStack.accessibilityLabel().string()
        XCTAssertEqual(label, "Temperature: 35°C")
        
    }
}
