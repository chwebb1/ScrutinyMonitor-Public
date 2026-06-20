import XCTest
import SwiftUI
import ViewInspector
@testable import ScrutinyMonitor

extension DriveHistoryChart: Inspectable {}

final class DriveHistoryChartTests: XCTestCase {
    func testDriveHistoryChartRenders() throws {
        let detail = DriveDetail(id: "1", device: nil, history: [], metadata: [:])
        let chart = DriveHistoryChart(detail: detail)
        
        let view = try chart.inspect()
        
        // Assert it has a VStack
        XCTAssertNoThrow(try view.vStack())
        
        // Assert the Picker exists and check its label
        let picker = try view.find(ViewType.Picker.self)
        XCTAssertEqual(try picker.labelView().text().string(), "Metric")
    }
    
    func testDriveHistoryChartAvailableMetrics() throws {
        let json = """
        {
            "date": "2023-10-27T10:00:00Z",
            "attrs": {
                "1": { "attribute_id": 1, "value": 100 }
            }
        }
        """.data(using: .utf8)!
        let smartResult = try JSONDecoder().decode(SmartResult.self, from: json)
        let metadataJson = """
        {
            "1": { "display_name": "Attribute One" }
        }
        """.data(using: .utf8)!
        let metadata = try JSONDecoder().decode([String: SmartAttributeMetadata].self, from: metadataJson)
        
        let detail = DriveDetail(id: "1", device: nil, history: [smartResult], metadata: metadata)
        let chart = DriveHistoryChart(detail: detail)
        
        let metrics = chart.availableMetrics
        XCTAssertEqual(metrics.count, 4) // temp, poh, pcc, + 1 attribute
        XCTAssertTrue(metrics.contains(.temperature))
        XCTAssertTrue(metrics.contains(.powerOnHours))
        XCTAssertTrue(metrics.contains(.powerCycleCount))
        XCTAssertTrue(metrics.contains(.attribute(id: "1", name: "Attribute One")))
    }

    func testYDomainHandlesExtremeValuesWithoutOverflow() throws {
        let minResult = try smartResult(date: "2023-10-27T10:00:00Z", metricValue: Int.min)
        let maxResult = try smartResult(date: "2023-10-28T10:00:00Z", metricValue: Int.max)
        let detail = DriveDetail(id: "1", device: nil, history: [minResult, maxResult], metadata: [:])
        let chart = DriveHistoryChart(detail: detail)

        XCTAssertEqual(chart.yDomain, Int.min...Int.max)
    }

    func testYDomainHandlesIntMinSingleValueWithoutOverflow() throws {
        let result = try smartResult(date: "2023-10-27T10:00:00Z", metricValue: Int.min)
        let detail = DriveDetail(id: "1", device: nil, history: [result], metadata: [:])
        let chart = DriveHistoryChart(detail: detail)

        XCTAssertEqual(chart.yDomain, Int.min...(Int.min + (Int.max / 10)))
    }

    private func smartResult(date: String, metricValue: Int) throws -> SmartResult {
        let json = """
        {
            "date": "\(date)",
            "temp": \(metricValue),
            "power_on_hours": \(metricValue),
            "power_cycle_count": \(metricValue)
        }
        """.data(using: .utf8)!

        return try JSONDecoder().decode(SmartResult.self, from: json)
    }
}
