import XCTest
@testable import ScrutinyMonitor

final class InstallationSnapshotTests: XCTestCase {

    // Helper to create a drive with a specific temperature
    private func makeDrive(id: String = UUID().uuidString, temperature: Int?) -> DriveSnapshot {
        DriveSnapshot(
            id: id,
            name: "Test Drive",
            model: "Model X",
            serial: "12345",
            protocolName: "NVMe",
            capacityBytes: 1000000000,
            statusCode: 0,
            temperature: temperature,
            powerOnHours: 100,
            collectorDate: "2023-10-27T10:00:00Z"
        )
    }

    // MARK: - status property tests

    func testStatusCritical() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 4,
            healthyDrives: 2,
            warningDrives: 1,
            criticalDrives: 1, // critical > 0 overrides warning
            devices: [],
            collectedAt: Date()
        )
        XCTAssertEqual(snapshot.status, .critical)
    }

    func testStatusWarning() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 4,
            healthyDrives: 3,
            warningDrives: 1,
            criticalDrives: 0,
            devices: [],
            collectedAt: Date()
        )
        XCTAssertEqual(snapshot.status, .warning)
    }

    func testStatusEmpty() {
        let snapshot = InstallationSnapshot(
            healthOK: true, // healthOK true -> empty
            totalDrives: 0,
            healthyDrives: 0,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [],
            collectedAt: Date()
        )
        XCTAssertEqual(snapshot.status, .empty)
    }

    func testStatusTotalZeroOffline() {
        let snapshot = InstallationSnapshot(
            healthOK: false, // healthOK false -> offline
            totalDrives: 0,
            healthyDrives: 0,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [],
            collectedAt: Date()
        )
        XCTAssertEqual(snapshot.status, .offline)
    }

    func testStatusHealthy() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 4,
            healthyDrives: 4,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [],
            collectedAt: Date()
        )
        XCTAssertEqual(snapshot.status, .healthy)
    }

    func testStatusOffline() {
        let snapshot = InstallationSnapshot(
            healthOK: false,
            totalDrives: 4,
            healthyDrives: 4,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [],
            collectedAt: Date()
        )
        XCTAssertEqual(snapshot.status, .offline)
    }

    // MARK: - Exhaustive Initializer Tests

    func testStatusCriticalOverridesAllWhenHealthOK() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: true,
                totalDrives: 1,
                healthyDrives: 0,
                warningDrives: 1,
                criticalDrives: 1,
                devices: [],
                collectedAt: Date()
            ).status,
            .critical
        )
    }

    func testStatusCriticalOverridesAllWhenHealthNotOK() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: false,
                totalDrives: 1,
                healthyDrives: 0,
                warningDrives: 1,
                criticalDrives: 1,
                devices: [],
                collectedAt: Date()
            ).status,
            .offline
        )
    }

    func testStatusWarningTakesPrecedenceOverHealthyWhenHealthOK() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: true,
                totalDrives: 1,
                healthyDrives: 0,
                warningDrives: 1,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .warning
        )
    }

    func testStatusWarningTakesPrecedenceOverHealthyWhenHealthNotOK() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: false,
                totalDrives: 1,
                healthyDrives: 0,
                warningDrives: 1,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .offline
        )
    }

    func testStatusEmptyWhenNoDrivesAndHealthOK() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: true,
                totalDrives: 0,
                healthyDrives: 0,
                warningDrives: 0,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .empty
        )
    }

    func testStatusOfflineWhenNoDrivesAndHealthNotOK() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: false,
                totalDrives: 0,
                healthyDrives: 0,
                warningDrives: 0,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .offline
        )
    }

    func testStatusHealthyWhenDrivesExistAndNoWarnings() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: true,
                totalDrives: 1,
                healthyDrives: 1,
                warningDrives: 0,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .healthy
        )
    }

    func testStatusOfflineWhenDrivesExistAndHealthNotOK() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: false,
                totalDrives: 1,
                healthyDrives: 1,
                warningDrives: 0,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .offline
        )
    }

    func testStatusHealthyWhenDrivesExistButCountsAreZero() {
        // Edge Case: (>0 drives, but 0 healthy/warning/critical)
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: true,
                totalDrives: 1,
                healthyDrives: 0,
                warningDrives: 0,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .healthy
        )
    }

    func testStatusOfflineWhenDrivesExistButCountsAreZeroAndHealthNotOK() {
        // Edge Case: (>0 drives, but 0 healthy/warning/critical)
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: false,
                totalDrives: 1,
                healthyDrives: 0,
                warningDrives: 0,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .offline
        )
    }

    func testStatusHandlesNegativeDriveCounts() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: true,
                totalDrives: -1,
                healthyDrives: 0,
                warningDrives: 0,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .empty
        )
    }

    func testNegativeDriveCountsClampToZero() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: -5,
            healthyDrives: -1,
            warningDrives: -2,
            criticalDrives: -3,
            devices: [],
            collectedAt: Date()
        )
        XCTAssertEqual(snapshot.totalDrives, 0)
        XCTAssertEqual(snapshot.healthyDrives, 0)
        XCTAssertEqual(snapshot.warningDrives, 0)
        XCTAssertEqual(snapshot.criticalDrives, 0)
    }

    func testStatusHandlesInconsistentCounts() {
        XCTAssertEqual(
            InstallationSnapshot(
                healthOK: true,
                totalDrives: 3,
                healthyDrives: 5,
                warningDrives: 0,
                criticalDrives: 0,
                devices: [],
                collectedAt: Date()
            ).status,
            .healthy
        )
    }

    // MARK: - averageTemperature property tests

    func testAverageTemperatureNoDevices() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 0,
            healthyDrives: 0,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [],
            collectedAt: Date()
        )
        XCTAssertNil(snapshot.averageTemperature)
    }

    func testAverageTemperatureNoValidTemperatures() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 2,
            healthyDrives: 2,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [makeDrive(temperature: nil), makeDrive(temperature: nil)],
            collectedAt: Date()
        )
        XCTAssertNil(snapshot.averageTemperature)
    }

    func testAverageTemperatureCalculation() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 4,
            healthyDrives: 4,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [
                makeDrive(temperature: 30),
                makeDrive(temperature: 40),
                makeDrive(temperature: 50),
                makeDrive(temperature: nil) // Should ignore nil
            ],
            collectedAt: Date()
        )
        // (30 + 40 + 50) / 3 = 40
        XCTAssertEqual(snapshot.averageTemperature, 40)
    }

    func testAverageTemperatureSingleDevice() {
        let snapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 1, warningDrives: 0, criticalDrives: 0, devices: [makeDrive(temperature: 42)], collectedAt: Date())
        XCTAssertEqual(snapshot.averageTemperature, 42)
    }

    func testAverageTemperatureSingleDeviceZero() {
        let snapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 1, warningDrives: 0, criticalDrives: 0, devices: [makeDrive(temperature: 0)], collectedAt: Date())
        XCTAssertEqual(snapshot.averageTemperature, 0)
    }

    func testAverageTemperatureTruncation() {
        // Test truncation (integer division): (30 + 33) / 2 = 31
        let snapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 2, warningDrives: 0, criticalDrives: 0, devices: [makeDrive(temperature: 30), makeDrive(temperature: 33)], collectedAt: Date())
        XCTAssertEqual(snapshot.averageTemperature, 31)
    }

    func testAverageTemperatureLargeDeviceCount() {
        let devices = (1...10).map { makeDrive(temperature: 30 + $0) }
        // sum(31...40) = 355. Integer division: 355 / 10 = 35 (truncated)
        let snapshot = InstallationSnapshot(healthOK: true, totalDrives: 10, healthyDrives: 10, warningDrives: 0, criticalDrives: 0, devices: devices, collectedAt: Date())
        XCTAssertEqual(snapshot.averageTemperature, 35)
    }

    func testAverageTemperatureMixedValuesAndZero() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 3,
            healthyDrives: 3,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [
                makeDrive(temperature: -10),
                makeDrive(temperature: 0),
                makeDrive(temperature: 10)
            ],
            collectedAt: Date()
        )
        // (-10 + 0 + 10) / 3 = 0
        XCTAssertEqual(snapshot.averageTemperature, 0)
    }

    func testAverageTemperatureAllNegativeValues() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 2,
            healthyDrives: 2,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [
                makeDrive(temperature: -10),
                makeDrive(temperature: -20)
            ],
            collectedAt: Date()
        )
        // (-10 + -20) / 2 = -15
        XCTAssertEqual(snapshot.averageTemperature, -15)
    }

    func testAverageTemperatureExtremeValues() {
        // Test large boundaries. They should be discarded as they exceed plausible limits.
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 2,
            healthyDrives: 2,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [
                makeDrive(temperature: Int.max),
                makeDrive(temperature: Int.min)
            ],
            collectedAt: Date()
        )
        // Since both values are discarded (nil), average is nil
        XCTAssertNil(snapshot.averageTemperature)
    }

    func testAverageTemperatureValidationBounds() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 5,
            healthyDrives: 5,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [
                makeDrive(temperature: -40),  // Exact lower bound (kept)
                makeDrive(temperature: 120),  // Exact upper bound (kept)
                makeDrive(temperature: -300), // Below lower bound -> nil
                makeDrive(temperature: 300),  // Above upper bound -> nil
                makeDrive(temperature: 40)    // In range -> 40
            ],
            collectedAt: Date()
        )
        // Sum: -40 + 120 + 40 = 120
        // Valid Count: 3
        // Average: 120 / 3 = 40
        XCTAssertEqual(snapshot.averageTemperature, 40)
    }

    func testNilTemperatureRemainsNil() {
        let drive = DriveSnapshot(
            id: "1", name: "Test", model: "A", serial: "B",
            protocolName: "C", capacityBytes: nil, statusCode: nil,
            temperature: nil, powerOnHours: nil, collectorDate: nil
        )
        XCTAssertNil(drive.temperature)
    }
}
