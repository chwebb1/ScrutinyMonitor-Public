import XCTest
import WidgetKit
@testable import ScrutinyMonitorWidget

final class ScrutinyMonitorWidgetTests: XCTestCase {
    
    func testEntryAverageTemperatureCalculation() {
        let drive1 = DriveSnapshot(id: "1", name: "D1", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: 40, powerOnHours: 0, collectorDate: nil)
        let drive2 = DriveSnapshot(id: "2", name: "D2", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: 50, powerOnHours: 0, collectorDate: nil)
        let drive3 = DriveSnapshot(id: "3", name: "D3", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: nil, powerOnHours: 0, collectorDate: nil)
        
        let testDate = Date(timeIntervalSince1970: 0)
        var inst = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        inst.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 3, healthyDrives: 3, warningDrives: 0, criticalDrives: 0, devices: [drive1, drive2, drive3], collectedAt: testDate)
        
        let totals = OverviewTotals(installations: [inst])
        let entry = ScrutinyMonitorWidgetEntry(date: testDate, installations: [inst], totals: totals)
        
        // (40 + 50) / 2 = 45. The nil temperature is ignored.
        XCTAssertEqual(entry.averageTemperature, 45)
    }

    func testEntrySortedDrivesIncludesAllDrives() {
        let testDate = Date(timeIntervalSince1970: 0)
        let driveHealthy = DriveSnapshot(id: "1", name: "B", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: 40, powerOnHours: 0, collectorDate: nil)
        let driveHealthy2 = DriveSnapshot(id: "2", name: "A", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: 40, powerOnHours: 0, collectorDate: nil)
        let driveWarning = DriveSnapshot(id: "3", name: "C", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 1, temperature: 40, powerOnHours: 0, collectorDate: nil)
        let driveFailed = DriveSnapshot(id: "4", name: "D", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 2, temperature: 40, powerOnHours: 0, collectorDate: nil)
        var inst = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        inst.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 4, healthyDrives: 2, warningDrives: 1, criticalDrives: 1, devices: [driveHealthy, driveHealthy2, driveWarning, driveFailed], collectedAt: testDate)

        let totals = OverviewTotals(installations: [inst])
        let entry = ScrutinyMonitorWidgetEntry(date: testDate, installations: [inst], totals: totals)
        XCTAssertEqual(entry.sortedDrives.map { $0.drive.name }, ["D", "C", "A", "B"])
    }

    func testEntrySortedDrivesFailedTakesPrecedence() {
        let testDate = Date(timeIntervalSince1970: 0)
        let driveHealthy = DriveSnapshot(id: "1", name: "B", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: 40, powerOnHours: 0, collectorDate: nil)
        let driveFailed = DriveSnapshot(id: "4", name: "D", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 2, temperature: 40, powerOnHours: 0, collectorDate: nil)
        var inst = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        inst.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 1, warningDrives: 0, criticalDrives: 1, devices: [driveHealthy, driveFailed], collectedAt: testDate)
        
        let totals = OverviewTotals(installations: [inst])
        let entry = ScrutinyMonitorWidgetEntry(date: testDate, installations: [inst], totals: totals)
        XCTAssertEqual(entry.sortedDrives.map { $0.drive.name }, ["D", "B"])
    }

    func testEntrySortedDrivesWarningTakesPrecedenceOverHealthy() {
        let testDate = Date(timeIntervalSince1970: 0)
        let driveHealthy = DriveSnapshot(id: "1", name: "B", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: 40, powerOnHours: 0, collectorDate: nil)
        let driveWarning = DriveSnapshot(id: "3", name: "C", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 1, temperature: 40, powerOnHours: 0, collectorDate: nil)
        var inst = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        inst.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 1, warningDrives: 1, criticalDrives: 0, devices: [driveHealthy, driveWarning], collectedAt: testDate)
        
        let totals = OverviewTotals(installations: [inst])
        let entry = ScrutinyMonitorWidgetEntry(date: testDate, installations: [inst], totals: totals)
        XCTAssertEqual(entry.sortedDrives.map { $0.drive.name }, ["C", "B"])
    }

    func testEntrySortedDrivesFailedTakesPrecedenceOverWarning() {
        let testDate = Date(timeIntervalSince1970: 0)
        let driveWarning = DriveSnapshot(id: "3", name: "C", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 1, temperature: 40, powerOnHours: 0, collectorDate: nil)
        let driveFailed = DriveSnapshot(id: "4", name: "D", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 2, temperature: 40, powerOnHours: 0, collectorDate: nil)
        var inst = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        inst.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 0, warningDrives: 1, criticalDrives: 1, devices: [driveWarning, driveFailed], collectedAt: testDate)

        let totals = OverviewTotals(installations: [inst])
        let entry = ScrutinyMonitorWidgetEntry(date: testDate, installations: [inst], totals: totals)
        XCTAssertEqual(entry.sortedDrives.map { $0.drive.name }, ["D", "C"])
    }

    func testEntrySortedDrivesHealthySortsAlphabetically() {
        let testDate = Date(timeIntervalSince1970: 0)
        let driveHealthy = DriveSnapshot(id: "1", name: "B", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: 40, powerOnHours: 0, collectorDate: nil)
        let driveHealthy2 = DriveSnapshot(id: "2", name: "A", model: "M", serial: "S", protocolName: "SATA", capacityBytes: 0, statusCode: 0, temperature: 40, powerOnHours: 0, collectorDate: nil)
        var inst = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        inst.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 2, warningDrives: 0, criticalDrives: 0, devices: [driveHealthy, driveHealthy2], collectedAt: testDate)

        let totals = OverviewTotals(installations: [inst])
        let entry = ScrutinyMonitorWidgetEntry(date: testDate, installations: [inst], totals: totals)
        XCTAssertEqual(entry.sortedDrives.map { $0.drive.name }, ["A", "B"])
    }
    
    func testStatusColor() {
        let testDate = Date(timeIntervalSince1970: 0)
        let entry = ScrutinyMonitorWidgetEntry(date: testDate, installations: [], totals: OverviewTotals(installations: []))
        
        XCTAssertEqual(entry.statusColor(for: .passed), .green)
        XCTAssertEqual(entry.statusColor(for: .warning), .orange)
        XCTAssertEqual(entry.statusColor(for: .failed), .red)
        XCTAssertEqual(entry.statusColor(for: .unknown), .secondary)
    }

    func testTempColor() {
        let testDate = Date(timeIntervalSince1970: 0)
        let entry = ScrutinyMonitorWidgetEntry(date: testDate, installations: [], totals: OverviewTotals(installations: []))
        
        XCTAssertEqual(entry.tempColor(for: 30), .green)
        XCTAssertEqual(entry.tempColor(for: 45), .orange)
        XCTAssertEqual(entry.tempColor(for: 55), .red)
    }
}
