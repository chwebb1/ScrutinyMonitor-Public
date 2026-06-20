import XCTest
@testable import ScrutinyMonitor

final class DriveListingCellTests: XCTestCase {

    func testDriveListingCellInitializationAndProperties() throws {
        // Given
        let id = "test-id"
        let index = 42
        let value = "test-value"

        // When
        let cell = DriveListingCell(id: id, index: index, value: value)

        // Then
        XCTAssertEqual(cell.id, id)
        XCTAssertEqual(cell.index, index)
        XCTAssertEqual(cell.value, value)
    }

    func testDriveListingCellEquality() {
        let cell1 = DriveListingCell(id: "1", index: 0, value: "A")
        let cell1Duplicate = DriveListingCell(id: "1", index: 0, value: "A")
        let cellDifferentID = DriveListingCell(id: "2", index: 0, value: "A")
        let cellDifferentIndex = DriveListingCell(id: "1", index: 1, value: "A")
        let cellDifferentValue = DriveListingCell(id: "1", index: 0, value: "B")

        XCTAssertEqual(cell1, cell1Duplicate)
        XCTAssertNotEqual(cell1, cellDifferentID)
        XCTAssertNotEqual(cell1, cellDifferentIndex)
        XCTAssertNotEqual(cell1, cellDifferentValue)
    }

    func testDriveListingCellHashability() {
        let cell1 = DriveListingCell(id: "1", index: 0, value: "A")
        let cell1Duplicate = DriveListingCell(id: "1", index: 0, value: "A")
        let cell2 = DriveListingCell(id: "2", index: 0, value: "A")

        XCTAssertEqual(cell1.hashValue, cell1Duplicate.hashValue)

        let setDuplicate = Set([cell1, cell1Duplicate])
        XCTAssertEqual(setDuplicate.count, 1)

        let setDistinct = Set([cell1, cell2])
        XCTAssertEqual(setDistinct.count, 2)
    }
}
