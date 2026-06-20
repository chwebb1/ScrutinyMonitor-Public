import XCTest
@testable import ScrutinyMonitor

final class ChartMetricTests: XCTestCase {
    func testTemperatureMetric() throws {
        let metric = ChartMetric.temperature
        XCTAssertEqual(metric.id, "temp")
        XCTAssertEqual(metric.title, "Temperature")
        
        let json = try XCTUnwrap("""
        {
            "temp": 42
        }
        """.data(using: .utf8))
        let result = try JSONDecoder().decode(SmartResult.self, from: json)
        XCTAssertEqual(metric.extractValue(from: result), 42)
    }

    func testPowerOnHoursMetric() throws {
        let metric = ChartMetric.powerOnHours
        XCTAssertEqual(metric.id, "poh")
        XCTAssertEqual(metric.title, "Power On Hours")
        
        let json = try XCTUnwrap("""
        {
            "power_on_hours": 1000
        }
        """.data(using: .utf8))
        let result = try JSONDecoder().decode(SmartResult.self, from: json)
        XCTAssertEqual(metric.extractValue(from: result), 1000)
    }

    func testPowerCycleCountMetric() throws {
        let metric = ChartMetric.powerCycleCount
        XCTAssertEqual(metric.id, "pcc")
        XCTAssertEqual(metric.title, "Power Cycle Count")
        
        let json = try XCTUnwrap("""
        {
            "power_cycle_count": 50
        }
        """.data(using: .utf8))
        let result = try JSONDecoder().decode(SmartResult.self, from: json)
        XCTAssertEqual(metric.extractValue(from: result), 50)
    }

    func testAttributeMetric() throws {
        let metric = ChartMetric.attribute(id: "1", name: "Read Error Rate")
        XCTAssertEqual(metric.id, "attr-1")
        XCTAssertEqual(metric.title, "Read Error Rate")
        
        let json1 = try XCTUnwrap("""
        {
            "attrs": {
                "1": { "attribute_id": 1, "value": 100 }
            }
        }
        """.data(using: .utf8))
        let result1 = try JSONDecoder().decode(SmartResult.self, from: json1)
        XCTAssertEqual(metric.extractValue(from: result1), 100)

        // Test transformedValue precedence
        let json2 = try XCTUnwrap("""
        {
            "attrs": {
                "1": { "attribute_id": 1, "value": 100, "transformed_value": 250 }
            }
        }
        """.data(using: .utf8))
        let result2 = try JSONDecoder().decode(SmartResult.self, from: json2)
        XCTAssertEqual(metric.extractValue(from: result2), 250)
    }
}
