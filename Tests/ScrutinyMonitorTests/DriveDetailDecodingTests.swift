import XCTest
@testable import ScrutinyMonitor

final class DriveDetailDecodingTests: XCTestCase {

    // MARK: - Flexible Int Decoding Tests (attribute_id)

    func testDecodeAttributeIDFromInt() throws {
        let json = """
        {"attribute_id": 1}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertEqual(result.attributeID, "1")
    }

    func testDecodeAttributeIDFromDouble() throws {
        let json = """
        {"attribute_id": 1.0}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertEqual(result.attributeID, "1")
    }

    func testDecodeAttributeIDFromString() throws {
        let json = """
        {"attribute_id": "1"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertEqual(result.attributeID, "1")
    }

    func testDecodeAttributeIDFromNVMeString() throws {
        let json = """
        {"attribute_id": "temperature"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertEqual(result.attributeID, "temperature")
    }

    func testDecodeAttributeIDFailureFromNull() throws {
        let json = """
        {"attribute_id": null}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertNil(result.attributeID)
    }

    func testDecodeAttributeIDMissing() throws {
        let json = """
        {}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertNil(result.attributeID)
    }

    // MARK: - Flexible Double Decoding Tests (failure_rate)

    func testDecodeFailureRateFromDouble() throws {
        let json = """
        {"failure_rate": 2.5}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertEqual(result.failureRate, 2.5)
    }

    func testDecodeFailureRateFromInt() throws {
        let json = """
        {"failure_rate": 2}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertEqual(result.failureRate, 2.0)
    }

    func testDecodeFailureRateFromString() throws {
        let json = """
        {"failure_rate": "2.5"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertEqual(result.failureRate, 2.5)
    }

    func testDecodeFailureRateFailureFromInvalidString() throws {
        let json = """
        {"failure_rate": "invalid"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(SmartAttributeDetail.self, from: json))
    }

    func testDecodeFailureRateFailureFromNull() throws {
        let json = """
        {"failure_rate": null}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertNil(result.failureRate)
    }

    func testDecodeFailureRateMissing() throws {
        let json = """
        {}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartAttributeDetail.self, from: json)
        XCTAssertNil(result.failureRate)
    }

    // MARK: - SmartResult Attributes Fallback Tests

    func testDecodeSmartResultAttributesDictionary() throws {
        let jsonString = """
        {
            "attrs": {
                "1": { "attribute_id": 1, "value": 100 }
            }
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartResult.self, from: json)
        XCTAssertEqual(result.attributes.count, 1)
        XCTAssertEqual(result.attributes["1"]?.value, 100)
    }

    func testDecodeSmartResultAttributesArrayOfObjects() throws {
        let jsonString = """
        {
            "attrs": [
                { "attribute_id": 1, "value": 100 }
            ]
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartResult.self, from: json)
        XCTAssertTrue(result.attributes.isEmpty)
    }

    func testDecodeSmartResultAttributesArrayOfStrings() throws {
        let jsonString = """
        {
            "attrs": ["something", "else"]
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartResult.self, from: json)
        XCTAssertTrue(result.attributes.isEmpty)
    }

    func testDecodeSmartResultAttributesInvalidType() throws {
        let jsonString = """
        {
            "attrs": 123
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(SmartResult.self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            if case .typeMismatch = decodingError {
                // Expected
            } else {
                XCTFail("Expected typeMismatch, got \(decodingError)")
            }
        }
    }

    func testDecodeSmartResultAttributesNull() throws {
        let jsonString = """
        {
            "attrs": null
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartResult.self, from: json)
        XCTAssertTrue(result.attributes.isEmpty)
    }

    func testDecodeSmartResultAttributesMissing() throws {
        let jsonString = """
        {}
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        let result = try decoder.decode(SmartResult.self, from: json)
        XCTAssertTrue(result.attributes.isEmpty)
    }

    func testDecodeSmartResultAttributesThrowsTypeMismatchOnString() throws {
        let jsonString = """
        {
            "attrs": "invalid_string"
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(SmartResult.self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            guard case .typeMismatch = decodingError else {
                XCTFail("Expected typeMismatch, got \(decodingError)")
                return
            }
            XCTAssert(true, "Expected typeMismatch was thrown")
        }
    }

    // MARK: - DriveDetailResponse Metadata Fallback Tests

    func testDecodeDriveDetailResponseMetadataThrowsTypeMismatchOnString() throws {
        let jsonString = """
        {
            "success": true,
            "metadata": "invalid_string"
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(DriveDetailResponse.self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            guard case .typeMismatch = decodingError else {
                XCTFail("Expected typeMismatch, got \(decodingError)")
                return
            }
            XCTAssert(true, "Expected typeMismatch was thrown")
        }
    }

    func testDecodeDriveDetailResponseThrowsKeyNotFoundWhenSuccessMissing() throws {
        let jsonString = """
        {
            "data": {}
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(DriveDetailResponse.self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            guard case .keyNotFound(let key, _) = decodingError else {
                XCTFail("Expected keyNotFound, got \(decodingError)")
                return
            }
            XCTAssertEqual(key.stringValue, "success")
        }
    }

    func testDecodeDriveDetailResponseThrowsTypeMismatchWhenSuccessIsNull() throws {
        let jsonString = """
        {
            "success": null,
            "data": {}
        }
        """
        let json = try XCTUnwrap(jsonString.data(using: .utf8))

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(DriveDetailResponse.self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            guard case .typeMismatch(let type, _) = decodingError else {
                XCTFail("Expected typeMismatch, got \(decodingError)")
                return
            }
            XCTAssertEqual(ObjectIdentifier(type), ObjectIdentifier(Bool.self))
        }
    }

    func testDecodeDriveDetailResponseArrayThrowsValueNotFoundForNullElement() throws {
        let json = try XCTUnwrap("[null]".data(using: .utf8))

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode([DriveDetailResponse].self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            guard case .valueNotFound(_, let context) = decodingError else {
                XCTFail("Expected valueNotFound, got \(decodingError)")
                return
            }
            XCTAssertEqual(context.codingPath.first?.intValue, 0)
        }
    }
}
