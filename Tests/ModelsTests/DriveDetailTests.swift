import XCTest
@testable import ScrutinyMonitor

final class DriveDetailTests: XCTestCase {
    func testInitWithoutLatestSmart() throws {
        let detail = DriveDetail(id: "1", device: nil, history: [], metadata: [:])
        XCTAssertEqual(detail.id, "1")
        XCTAssertTrue(detail.attributes.isEmpty)
    }

    func testInitWithLatestSmart() throws {
        let smartJson = """
        {
            "attrs": {
                "1": { "attribute_id": 1, "value": 100 },
                "5": { "attribute_id": 5, "value": 200 }
            }
        }
        """
        let smartData = smartJson.data(using: .utf8)!
        let smartResult = try JSONDecoder().decode(SmartResult.self, from: smartData)

        let metadataJson = """
        {
            "display_name": "Raw Read Error Rate"
        }
        """
        let metadataData = metadataJson.data(using: .utf8)!
        let metadata = try JSONDecoder().decode(SmartAttributeMetadata.self, from: metadataData)

        let detail = DriveDetail(id: "2", device: nil, history: [smartResult], metadata: ["1": metadata])
        XCTAssertEqual(detail.attributes.count, 2)
        XCTAssertEqual(detail.attributes[0].id, "1")
        XCTAssertEqual(detail.attributes[0].metadata?.displayName, "Raw Read Error Rate")
        XCTAssertEqual(detail.attributes[1].id, "5")
    }

    func testDriveDetailInitializationWithNilSmartResult() throws {
        // Models cannot be mocked easily if they are purely Decodable without init,
        // so we decode them from JSON.
        let json = """
        {
            "success": true,
            "data": {
                "smart_results": []
            }
        }
        """.data(using: .utf8)!

        let _ = try JSONDecoder().decode(DriveDetailResponse.self, from: json)

        let driveDetail = DriveDetail(
            id: "test-id",
            device: nil,
            history: [],
            metadata: [:]
        )

        XCTAssertEqual(driveDetail.id, "test-id")
        XCTAssertNil(driveDetail.device)
        XCTAssertNil(driveDetail.latestSmart)
        XCTAssertTrue(driveDetail.metadata.isEmpty)
        XCTAssertTrue(driveDetail.attributes.isEmpty)
    }

    func testDriveDetailInitializationWithEmptyAttributes() throws {
        let json = """
        {
            "date": "2023-10-27T10:00:00Z"
        }
        """.data(using: .utf8)!

        let smartResult = try JSONDecoder().decode(SmartResult.self, from: json)

        let driveDetail = DriveDetail(
            id: "test-id",
            device: nil,
            history: [smartResult],
            metadata: [:]
        )

        XCTAssertEqual(driveDetail.id, "test-id")
        XCTAssertNotNil(driveDetail.latestSmart)
        XCTAssertTrue(driveDetail.attributes.isEmpty)
    }

    func testDriveDetailInitializationWithAttributesSorting() throws {
        let json = """
        {
            "date": "2023-10-27T10:00:00Z",
            "attrs": {
                "3": {
                    "attribute_id": 3,
                    "value": 300
                },
                "1": {
                    "attribute_id": 1,
                    "value": 100
                },
                "string_attr": {
                    "value": 999
                },
                "2": {
                    "attribute_id": 2,
                    "value": 200
                }
            }
        }
        """.data(using: .utf8)!

        let smartResult = try JSONDecoder().decode(SmartResult.self, from: json)

        let metadataJson = """
        {
            "1": {
                "display_name": "Attribute One"
            }
        }
        """.data(using: .utf8)!

        let metadata = try JSONDecoder().decode([String: SmartAttributeMetadata].self, from: metadataJson)

        let driveDetail = DriveDetail(
            id: "test-id",
            device: nil,
            history: [smartResult],
            metadata: metadata
        )

        XCTAssertEqual(driveDetail.attributes.count, 4)

        // Sorting should put integers first based on localizedStandardCompare or custom sort:
        // custom sort:
        // if let lhsID = Int(lhs.id), let rhsID = Int(rhs.id) { return lhsID < rhsID }
        // else return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending

        // Let's verify standard sort order output:
        let ids = driveDetail.attributes.map { $0.id }
        XCTAssertTrue(ids.contains("1"))
        XCTAssertTrue(ids.contains("2"))
        XCTAssertTrue(ids.contains("3"))
        XCTAssertTrue(ids.contains("string_attr"))

        // Specific checks: 1 comes before 2, 2 before 3.
        XCTAssertEqual(ids.filter { Int($0) != nil }, ["1", "2", "3"])

        // Check metadata mapping
        let attr1 = driveDetail.attributes.first(where: { $0.id == "1" })
        XCTAssertNotNil(attr1)
        XCTAssertEqual(attr1?.metadata?.displayName, "Attribute One")

        // Check missing metadata mapping
        let attr2 = driveDetail.attributes.first(where: { $0.id == "2" })
        XCTAssertNotNil(attr2)
        XCTAssertNil(attr2?.metadata)
    }

    func testSmartResultDecoding() throws {
        let json = """
        {
            "date": "2023-10-27T10:00:00Z",
            "scrutiny_uuid": "some-uuid",
            "device_protocol": "NVMe",
            "temp": 40,
            "power_on_hours": 100,
            "power_cycle_count": 10,
            "attrs": {
                "1": {
                    "attribute_id": 1,
                    "value": 100,
                    "thresh": 50,
                    "worst": 100,
                    "raw_value": 0,
                    "status": 0
                }
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartResult.self, from: json)

        XCTAssertEqual(result.date, "2023-10-27T10:00:00Z")
        XCTAssertEqual(result.scrutinyUUID, "some-uuid")
        XCTAssertEqual(result.deviceProtocol, "NVMe")
        XCTAssertEqual(result.temperature?.value, 40)
        XCTAssertEqual(result.powerOnHours?.value, 100)
        XCTAssertEqual(result.powerCycleCount?.value, 10)
        XCTAssertEqual(result.attributes.count, 1)
        XCTAssertEqual(result.attributes["1"]?.attributeID, "1")
        XCTAssertEqual(result.attributes["1"]?.value, 100)
        XCTAssertEqual(result.attributes["1"]?.threshold, 50)
    }

    func testDriveDetailResponseDecoding() throws {
        let json = """
        {
            "success": true,
            "data": {
                "smart_results": []
            },
            "error": "some error",
            "errors": ["err1", "err2"]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(DriveDetailResponse.self, from: json)

        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.data)
        XCTAssertEqual(response.data?.smartResults.count, 0)
        XCTAssertEqual(response.error, "some error")
        XCTAssertEqual(response.errors, ["err1", "err2"])
    }

    func testDriveDetailResponseDecodingEmptyMetadataArray() throws {
        // Some backends return `[]` instead of `{}` when the metadata dictionary is empty
        let json = """
        {
            "success": true,
            "metadata": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(DriveDetailResponse.self, from: json)

        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.metadata)
        XCTAssertTrue(response.metadata!.isEmpty)
    }

    func testDriveDetailDataDecodingMissingSmartResults() throws {
        // If a drive has no smart history, the backend might omit smart_results
        let json = """
        {
            "device": {
                "device_name": "Test Drive"
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let data = try decoder.decode(DriveDetailData.self, from: json)

        XCTAssertNotNil(data.device)
        XCTAssertEqual(data.smartResults.count, 0)
    }

    func testSmartResultDecodingEmptyAttributesArray() throws {
        // If a smart result has no attributes, the backend might return `[]` instead of `{}`
        let json = """
        {
            "date": "2023-10-27T10:00:00Z",
            "attrs": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartResult.self, from: json)

        XCTAssertEqual(result.date, "2023-10-27T10:00:00Z")
        XCTAssertNotNil(result.attributes)
        XCTAssertTrue(result.attributes.isEmpty)
    }

    func testSmartAttributeDetailDecodingFlexibleType() throws {
        // FlexibleType has an extension on KeyedDecodingContainer in DriveDetail.swift
        // Let's decode SmartAttributeDetail which uses decodeFlexibleIntIfPresent
        let json = """
        {
            "attribute_id": 1,
            "value": 100.5,
            "thresh": "50",
            "failure_rate": 0.5,
            "status": "2"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let detail = try decoder.decode(SmartAttributeDetail.self, from: json)

        XCTAssertEqual(detail.attributeID, "1") // Decoded to String
        XCTAssertEqual(detail.value, 100) // Double decoded to Int
        XCTAssertEqual(detail.threshold, 50) // String decoded to Int
        XCTAssertEqual(detail.status, 2) // String decoded to Int
        XCTAssertEqual(detail.failureRate, 0.5) // Double decoded directly
    }

    func testSmartAttributeDetailDecodingWithIncompatibleType() throws {
        let json = """
        {
            "attribute_id": 1,
            "value": ["an", "array"]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(SmartAttributeDetail.self, from: json)
            XCTFail("Expected decoding to fail with dataCorrupted or typeMismatch")
        } catch let DecodingError.typeMismatch(type, context) {
            // The type mismatch should correctly report the primary expected type (Int.self)
            XCTAssertEqual(ObjectIdentifier(type), ObjectIdentifier(Int.self))
            XCTAssertEqual(context.codingPath.last?.stringValue, "value")
        } catch {
            XCTFail("Expected DecodingError.typeMismatch, got \(error)")
        }
    }

    func testSmartAttributeDetailDecodingWithInvalidString() throws {
        let json = """
        {
            "attribute_id": 1,
            "value": "not_a_number"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(SmartAttributeDetail.self, from: json)
            XCTFail("Expected decoding to fail with dataCorrupted")
        } catch let DecodingError.dataCorrupted(context) {
            XCTAssertEqual(context.codingPath.last?.stringValue, "value")
            XCTAssertTrue(context.debugDescription.contains("not_a_number"))
        } catch {
            XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
        }
    }

    func testSmartAttributeDetailDecodingWithStringValue() throws {
        // Verifies that string representations of numbers ("123", "50") are correctly coerced to their numeric types
        let json = """
        {
            "attribute_id": "1",
            "value": "123",
            "thresh": "50"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let detail = try decoder.decode(SmartAttributeDetail.self, from: json)

        XCTAssertEqual(detail.attributeID, "1")
        XCTAssertEqual(detail.value, 123)
        XCTAssertEqual(detail.threshold, 50)
    }

    func testSmartAttributeDetailDecodingWithIncompatibleAttributeID() throws {
        let json = """
        {
            "attribute_id": ["invalid", "array"],
            "value": 123
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(SmartAttributeDetail.self, from: json)
            XCTFail("Expected decoding to fail with typeMismatch")
        } catch let DecodingError.typeMismatch(type, context) {
            // attribute_id tries Int then String, so the mismatch will be on String.self
            XCTAssertEqual(ObjectIdentifier(type), ObjectIdentifier(String.self))
            XCTAssertEqual(context.codingPath.last?.stringValue, "attribute_id")
        } catch {
            XCTFail("Expected DecodingError.typeMismatch, got \(error)")
        }
    }

    func testSmartAttributeDetailDecodingWithMissingOrNilValues() throws {
        let json = """
        {
            "attribute_id": 1,
            "value": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let detail = try decoder.decode(SmartAttributeDetail.self, from: json)

        XCTAssertEqual(detail.attributeID, "1")
        XCTAssertNil(detail.value)
        XCTAssertNil(detail.threshold)
    }
}
