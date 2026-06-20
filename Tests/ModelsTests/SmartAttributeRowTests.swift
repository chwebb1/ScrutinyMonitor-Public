import XCTest
@testable import ScrutinyMonitor

final class SmartAttributeRowTests: XCTestCase {

    private func createRow(
        id: String,
        attributeJson: String = "{}",
        metadataJson: String? = nil
    ) throws -> SmartAttributeRow {
        let attributeData = attributeJson.data(using: .utf8)!
        let attribute = try JSONDecoder().decode(SmartAttributeDetail.self, from: attributeData)

        var metadata: SmartAttributeMetadata?
        if let metadataJson = metadataJson {
            let metadataData = metadataJson.data(using: .utf8)!
            metadata = try JSONDecoder().decode(SmartAttributeMetadata.self, from: metadataData)
        }

        return SmartAttributeRow(id: id, attribute: attribute, metadata: metadata)
    }

    func testNameWithMetadata() throws {
        let row = try createRow(
            id: "5",
            metadataJson: """
            {
                "display_name": "Reallocated Sectors Count"
            }
            """
        )
        XCTAssertEqual(row.name, "Reallocated Sectors Count")
    }

    func testNameWithoutMetadata() throws {
        let row = try createRow(id: "9")
        XCTAssertEqual(row.name, "Attribute 9")
    }

    func testRawTextWithRawString() throws {
        let row = try createRow(
            id: "9",
            attributeJson: """
            {
                "raw_string": "1234 hours",
                "raw_value": 1234
            }
            """
        )
        XCTAssertEqual(row.rawText, "1234 hours")
    }

    func testRawTextWithEmptyRawString() throws {
        let row = try createRow(
            id: "9",
            attributeJson: """
            {
                "raw_string": "",
                "raw_value": 1234
            }
            """
        )
        XCTAssertEqual(row.rawText, "1234")
    }

    func testRawTextWithOnlyRawValue() throws {
        let row = try createRow(
            id: "9",
            attributeJson: """
            {
                "raw_value": 5678
            }
            """
        )
        XCTAssertEqual(row.rawText, "5678")
    }

    func testRawTextWithoutRawStringOrValue() throws {
        let row = try createRow(id: "9")
        XCTAssertEqual(row.rawText, "-")
    }

    func testValueTextWithTransformedValue() throws {
        let row = try createRow(
            id: "9",
            attributeJson: """
            {
                "transformed_value": 100,
                "value": 200
            }
            """
        )
        XCTAssertEqual(row.valueText, "100")
    }

    func testValueTextWithOnlyValue() throws {
        let row = try createRow(
            id: "9",
            attributeJson: """
            {
                "value": 200
            }
            """
        )
        XCTAssertEqual(row.valueText, "200")
    }

    func testValueTextWithoutTransformedOrValue() throws {
        let row = try createRow(id: "9")
        XCTAssertEqual(row.valueText, "-")
    }

    func testShouldShowIdentifierTrue() throws {
        let row = try createRow(
            id: "Power_On_Hours",
            metadataJson: """
            {
                "display_name": "Power On Hours"
            }
            """
        )
        XCTAssertFalse(row.shouldShowIdentifier)
    }

    func testShouldShowIdentifierTrueWhenDifferent() throws {
        let row = try createRow(
            id: "9",
            metadataJson: """
            {
                "display_name": "Power On Hours"
            }
            """
        )
        XCTAssertTrue(row.shouldShowIdentifier)
    }

    func testShouldShowIdentifierFalseWhenEmpty() throws {
        let row = try createRow(
            id: "",
            metadataJson: """
            {
                "display_name": "Power On Hours"
            }
            """
        )
        XCTAssertFalse(row.shouldShowIdentifier)
    }

    func testShouldShowIdentifierFalseWhenNormalizedMatches() throws {
        let row = try createRow(
            id: "power_on_hours",
            metadataJson: """
            {
                "display_name": "Power-On Hours"
            }
            """
        )
        XCTAssertFalse(row.shouldShowIdentifier)

        let row2 = try createRow(
            id: "power_on_hours",
            metadataJson: """
            {
                "display_name": "Power On Hours"
            }
            """
        )
        XCTAssertFalse(row2.shouldShowIdentifier)
    }

    func testSmartAttributeRowEquality() throws {
        let row1 = try createRow(id: "9", attributeJson: "{\"value\": 200}")
        let row1Duplicate = try createRow(id: "9", attributeJson: "{\"value\": 200}")
        let rowDifferentID = try createRow(id: "10", attributeJson: "{\"value\": 200}")
        let rowDifferentValue = try createRow(id: "9", attributeJson: "{\"value\": 201}")
        let rowWithMetadata = try createRow(id: "9", attributeJson: "{\"value\": 200}", metadataJson: "{\"display_name\": \"Power On Hours\"}")

        XCTAssertEqual(row1, row1Duplicate)
        XCTAssertNotEqual(row1, rowDifferentID)
        XCTAssertNotEqual(row1, rowDifferentValue)
        XCTAssertNotEqual(row1, rowWithMetadata)
    }

    func testSmartAttributeRowHashability() throws {
        let row1 = try createRow(id: "9", attributeJson: "{\"value\": 200}")
        let row1Duplicate = try createRow(id: "9", attributeJson: "{\"value\": 200}")
        let row2 = try createRow(id: "10", attributeJson: "{\"value\": 200}")

        XCTAssertEqual(row1.hashValue, row1Duplicate.hashValue)

        let setDuplicate = Set([row1, row1Duplicate])
        XCTAssertEqual(setDuplicate.count, 1)

        let setDistinct = Set([row1, row2])
        XCTAssertEqual(setDistinct.count, 2)

        let rowDifferentValue = try createRow(id: "9", attributeJson: "{\"value\": 201}")
        let setDistinctData = Set([row1, rowDifferentValue])
        XCTAssertEqual(setDistinctData.count, 2)
    }
}
