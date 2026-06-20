import XCTest
@testable import ScrutinyMonitor

final class OverviewDriveTests: XCTestCase {

    // MARK: - Constants
    
    private let defaultTestURL = URL(string: "http://example.com") ?? URL(fileURLWithPath: "/")
    private let differentTestURL = URL(string: "http://different.com") ?? URL(fileURLWithPath: "/")

    // MARK: - Initialization & ID Tests

    func testOverviewDriveInitializationAndID() {
        let installationID = UUID()
        let driveID = "disk1"
        let overviewDrive = makeOverviewDrive(installationID: installationID, driveID: driveID)

        XCTAssertEqual(overviewDrive.installation.id, installationID)
        XCTAssertEqual(overviewDrive.drive.id, driveID)
        
        let expectedID = "\(installationID.uuidString)-\(driveID)"
        XCTAssertEqual(overviewDrive.id, expectedID)
    }

    // MARK: - Equality Tests

    func testOverviewDriveEquality() {
        let sharedInstallationID = UUID()

        let overviewDrive1 = makeOverviewDrive(installationID: sharedInstallationID)
        let overviewDrive1Duplicate = makeOverviewDrive(installationID: sharedInstallationID)
        let overviewDrive1Triplicate = makeOverviewDrive(installationID: sharedInstallationID)

        // Identity
        XCTAssertEqual(overviewDrive1, overviewDrive1Duplicate)

        // Symmetry
        XCTAssertEqual(overviewDrive1Duplicate, overviewDrive1)

        // Transitivity
        XCTAssertEqual(overviewDrive1Duplicate, overviewDrive1Triplicate)
        XCTAssertEqual(overviewDrive1, overviewDrive1Triplicate)
    }

    func testOverviewDriveInequalityGranularity() {
        let baseID = UUID()
        let baseDrive = makeOverviewDrive(installationID: baseID)

        // Installation variations
        let driveWithDifferentInstallationID = makeOverviewDrive(installationID: UUID())
        let driveWithDifferentInstallationName = makeOverviewDrive(installationID: baseID, installationName: "Different")
        let driveWithDifferentBaseURL = makeOverviewDrive(installationID: baseID, baseURL: differentTestURL)
        let driveWithDifferentAPIToken = makeOverviewDrive(installationID: baseID, apiToken: "token".data(using: .utf8)!)

        // Drive variations
        let driveWithDifferentDriveID = makeOverviewDrive(installationID: baseID, driveID: "disk2")
        let driveWithDifferentDriveName = makeOverviewDrive(installationID: baseID, driveName: "Disk 2")
        let driveWithDifferentModel = makeOverviewDrive(installationID: baseID, model: "Different Model")
        let driveWithDifferentSerial = makeOverviewDrive(installationID: baseID, serial: "999")
        let driveWithDifferentProtocolName = makeOverviewDrive(installationID: baseID, protocolName: "NVMe")
        let driveWithDifferentCapacityBytes = makeOverviewDrive(installationID: baseID, capacityBytes: 200)
        let driveWithDifferentStatusCode = makeOverviewDrive(installationID: baseID, statusCode: 2)
        let driveWithDifferentTemperature = makeOverviewDrive(installationID: baseID, temperature: 50)
        let driveWithDifferentPowerOnHours = makeOverviewDrive(installationID: baseID, powerOnHours: 20)
        let driveWithDifferentCollectorDate = makeOverviewDrive(installationID: baseID, collectorDate: "2023-01-02T00:00:00Z")

        XCTAssertNotEqual(baseDrive, driveWithDifferentInstallationID, "Drives with different installation IDs should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentInstallationName, "Drives with different installation names should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentBaseURL, "Drives with different base URLs should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentAPIToken, "Drives with different API tokens should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentDriveID, "Drives with different drive IDs should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentDriveName, "Drives with different drive names should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentModel, "Drives with different models should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentSerial, "Drives with different serials should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentProtocolName, "Drives with different protocol names should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentCapacityBytes, "Drives with different capacity bytes should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentStatusCode, "Drives with different status codes should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentTemperature, "Drives with different temperatures should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentPowerOnHours, "Drives with different power on hours should not be equal")
        XCTAssertNotEqual(baseDrive, driveWithDifferentCollectorDate, "Drives with different collector dates should not be equal")
    }

    // MARK: - Hashability Tests

    func testOverviewDriveHashability() {
        let sharedInstallationID = UUID()

        let overviewDrive1 = makeOverviewDrive(installationID: sharedInstallationID)
        let overviewDrive1Duplicate = makeOverviewDrive(installationID: sharedInstallationID)
        let overviewDrive2 = makeOverviewDrive()

        // Equal objects must have equal hashes
        XCTAssertEqual(overviewDrive1.hashValue, overviewDrive1Duplicate.hashValue)

        // Ensure the precondition for distinct set verification is explicit
        XCTAssertNotEqual(overviewDrive1, overviewDrive2)

        // Set Deduplication Verification
        let driveSetDuplicate = Set([overviewDrive1, overviewDrive1Duplicate])
        XCTAssertEqual(driveSetDuplicate.count, 1)

        // Distinct Objects in Set Verification
        let driveSetDistinct = Set([overviewDrive1, overviewDrive2])
        XCTAssertEqual(driveSetDistinct.count, 2)
    }

    func testOverviewDriveEqualityConsidersAllProperties() {
        let sharedInstallationID = UUID()
        let overviewDrive1 = makeOverviewDrive(installationID: sharedInstallationID, installationName: "Inst A")
        let overviewDrive2 = makeOverviewDrive(installationID: sharedInstallationID, installationName: "Inst B")

        // OverviewDrive's synthesized Equatable compares all properties, so different installations yield unequal drives despite matching computed id.
        XCTAssertEqual(overviewDrive1.id, overviewDrive2.id)
        XCTAssertNotEqual(overviewDrive1, overviewDrive2)
    }

    // MARK: - Helpers

    /// Creates a mock `OverviewDrive` for testing.
    /// - Note: If called without an explicit `installationID`, it generates a fresh UUID every time,
    ///         ensuring that instances represent distinct records by default.
    private func makeOverviewDrive(
        installationID: UUID = UUID(),
        installationName: String = "Inst",
        baseURL: URL? = nil,
        apiToken: Data = Data(),
        driveID: String = "disk1",
        driveName: String = "Disk",
        model: String = "Model",
        serial: String = "123",
        protocolName: String = "SATA",
        capacityBytes: Int64 = 100,
        statusCode: Int = 1,
        temperature: Int = 40,
        powerOnHours: Int = 10,
        collectorDate: String = "2023-01-01T00:00:00Z"
    ) -> OverviewDrive {
        let installation = ScrutinyInstallation(
            id: installationID,
            name: installationName,
            baseURL: baseURL ?? defaultTestURL,
            apiToken: apiToken
        )

        let drive = DriveSnapshot(
            id: driveID,
            name: driveName,
            model: model,
            serial: serial,
            protocolName: protocolName,
            capacityBytes: capacityBytes,
            statusCode: statusCode,
            temperature: temperature,
            powerOnHours: powerOnHours,
            collectorDate: collectorDate
        )

        return OverviewDrive(installation: installation, drive: drive)
    }
}
