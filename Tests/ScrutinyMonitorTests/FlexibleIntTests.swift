import XCTest
@testable import ScrutinyMonitor

final class FlexibleIntTests: XCTestCase {

    struct TestModel: Decodable {
        let status: FlexibleInt
    }

    func testDecodeFromInt() throws {
        let json = """
        {"status": 1}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(TestModel.self, from: json)
        XCTAssertEqual(result.status.value, 1)
    }

    func testDecodeFromDouble() throws {
        let json = """
        {"status": 1.0}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(TestModel.self, from: json)
        XCTAssertEqual(result.status.value, 1)
    }

    func testDecodeFromString() throws {
        let json = """
        {"status": "1"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let result = try decoder.decode(TestModel.self, from: json)
        XCTAssertEqual(result.status.value, 1)
    }

    func testDecodeFailureFromInvalidString() {
        let json = """
        {"status": "invalid"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(TestModel.self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected a DecodingError")
                return
            }
            switch decodingError {
            case .typeMismatch(let type, let context):
                XCTAssertEqual(ObjectIdentifier(type), ObjectIdentifier(Int.self))
                XCTAssertEqual(context.debugDescription, "Expected an integer-compatible value.")
            default:
                XCTFail("Expected typeMismatch error")
            }
        }
    }

    func testDecodeFailureFromBoolean() {
        let json = """
        {"status": true}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(TestModel.self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected a DecodingError")
                return
            }
            switch decodingError {
            case .typeMismatch(let type, let context):
                XCTAssertEqual(ObjectIdentifier(type), ObjectIdentifier(Int.self))
                XCTAssertEqual(context.debugDescription, "Expected an integer-compatible value.")
            default:
                XCTFail("Expected typeMismatch error")
            }
        }
    }

    func testDecodeFailureFromNull() {
        let json = """
        {"status": null}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(TestModel.self, from: json)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected a DecodingError")
                return
            }
            switch decodingError {
            case .valueNotFound(let type, _):
                XCTAssertEqual(ObjectIdentifier(type), ObjectIdentifier(Int.self))
            default:
                XCTFail("Expected valueNotFound error")
            }
        }
    }
}
