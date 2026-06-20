import XCTest
@testable import ScrutinyMonitor

final class DriveListingRowTests: XCTestCase {

    func testDriveListingRowInitialization() throws {
        let drive = DriveSnapshot(
            id: "disk1",
            name: "Macintosh HD",
            model: "APPLE SSD AP0512M",
            serial: "C02...",
            protocolName: "NVMe",
            capacityBytes: 500_000_000_000,
            statusCode: 1,
            temperature: 40,
            powerOnHours: 1000,
            collectorDate: "2023-10-27T10:00:00Z"
        )

        let values = ["Value1", "Value2", "Value3"]

        let row = DriveListingRow(
            id: "row-1",
            drive: drive,
            values: values
        )

        XCTAssertEqual(row.id, "row-1")
        XCTAssertEqual(row.drive.id, drive.id)
        XCTAssertEqual(row.values, values)
        XCTAssertEqual(row.cells.count, 3)

        for (index, cell) in row.cells.enumerated() {
            XCTAssertEqual(cell.id, "row-1-column-\(index)")
            XCTAssertEqual(cell.index, index)
            XCTAssertEqual(cell.value, values[index])
        }
    }

    func testDriveListingRowInitializationEmptyValues() throws {
        let drive = DriveSnapshot(
            id: "disk2",
            name: "External Drive",
            model: "WD My Passport",
            serial: "WDC...",
            protocolName: "USB",
            capacityBytes: 1_000_000_000_000,
            statusCode: 2,
            temperature: 35,
            powerOnHours: 500,
            collectorDate: "2023-10-27T11:00:00Z"
        )

        let row = DriveListingRow(
            id: "row-empty",
            drive: drive,
            values: []
        )

        XCTAssertEqual(row.id, "row-empty")
        XCTAssertEqual(row.drive.id, drive.id)
        XCTAssertTrue(row.values.isEmpty)
        XCTAssertTrue(row.cells.isEmpty)
    }

    func testDriveListingRowEquality() throws {
        let drive1 = DriveSnapshot(id: "d1", name: "D", model: "M", serial: "S", protocolName: "P", capacityBytes: 100, statusCode: 1, temperature: 40, powerOnHours: 100, collectorDate: "2023")
        let drive2 = DriveSnapshot(id: "d2", name: "D", model: "M", serial: "S", protocolName: "P", capacityBytes: 100, statusCode: 1, temperature: 40, powerOnHours: 100, collectorDate: "2023")

        let row1 = DriveListingRow(id: "r1", drive: drive1, values: ["A", "B"])
        let row1Duplicate = DriveListingRow(id: "r1", drive: drive1, values: ["A", "B"])
        let rowDifferentID = DriveListingRow(id: "r2", drive: drive1, values: ["A", "B"])
        let rowDifferentDrive = DriveListingRow(id: "r1", drive: drive2, values: ["A", "B"])
        let rowDifferentValues = DriveListingRow(id: "r1", drive: drive1, values: ["A", "C"])

        // Cells are recomputed from initialization but equality still holds
        XCTAssertEqual(row1, row1Duplicate)
        XCTAssertNotEqual(row1, rowDifferentID)
        XCTAssertNotEqual(row1, rowDifferentDrive)
        XCTAssertNotEqual(row1, rowDifferentValues)
    }

    func testDriveListingRowHashability() throws {
        let drive1 = DriveSnapshot(id: "d1", name: "D", model: "M", serial: "S", protocolName: "P", capacityBytes: 100, statusCode: 1, temperature: 40, powerOnHours: 100, collectorDate: "2023")
        let row1 = DriveListingRow(id: "r1", drive: drive1, values: ["A"])
        let row1Duplicate = DriveListingRow(id: "r1", drive: drive1, values: ["A"])
        let row2 = DriveListingRow(id: "r2", drive: drive1, values: ["A"])

        XCTAssertEqual(row1.hashValue, row1Duplicate.hashValue)

        let setDuplicate = Set([row1, row1Duplicate])
        XCTAssertEqual(setDuplicate.count, 1)

        let setDistinct = Set([row1, row2])
        XCTAssertEqual(setDistinct.count, 2)

        let rowDifferentValues = DriveListingRow(id: "r1", drive: drive1, values: ["A", "B"])
        let setDistinctData = Set([row1, rowDifferentValues])
        XCTAssertEqual(setDistinctData.count, 2)
    }
}
