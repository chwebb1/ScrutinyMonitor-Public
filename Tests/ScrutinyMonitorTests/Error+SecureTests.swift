import XCTest
@testable import ScrutinyMonitor

final class ErrorSecureTests: XCTestCase {

    func testScrutinyClientErrorSecureDescription() {
        enum CustomTestError: Error {
            case generic
        }

        let errors: [ScrutinyClientError] = [
            .invalidResponse,
            .httpStatus(404),
            .api("Test API Error"),
            .decoding(URLError(.badURL)),
            .decoding(NSError(domain: "TestDomain", code: -1, userInfo: nil)),
            .decoding(CustomTestError.generic)
        ]

        for error in errors {
            XCTAssertEqual(error.secureDescription, error.localizedDescription)
        }
    }

    func testInstallationValidationErrorSecureDescription() {
        let errors: [InstallationValidationError] = [
            .emptyURL,
            .invalidURL,
            .insecureURL,
            .unsupportedScheme,
            .invalidInput("Test invalid input")
        ]

        for error in errors {
            XCTAssertEqual(error.secureDescription, error.localizedDescription)
        }
    }

    func testSettingsSyncErrorSecureDescription() {
        let errors: [SettingsSyncError] = [
            .providerNotConfigured(.webDAV),
            .invalidWebDAVURL,
            .insecureWebDAVURL,
            .serverRejectedRequest(403),
            .missingHTTPResponse
        ]

        for error in errors {
            XCTAssertEqual(error.secureDescription, error.localizedDescription)
        }
    }

    func testURLErrorSecureDescription() {
        let urlError1 = URLError(.cannotFindHost)
        XCTAssertEqual(urlError1.secureDescription, "A network connection error occurred while communicating with the server (Code: -1003).")

        let urlError2 = URLError(.cannotConnectToHost)
        XCTAssertEqual(urlError2.secureDescription, "A network connection error occurred while communicating with the server (Code: -1004).")
    }

    func testNestedURLErrorSecureDescription() {
        let underlying = URLError(.timedOut)
        let wrapped = NSError(
            domain: "Wrapper",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )

        XCTAssertEqual(wrapped.secureDescription, "A network connection error occurred while communicating with the server (Code: -1001).")
    }

    func testUnexpectedErrorSecureDescription() {
        enum CustomTestError: Error {
            case generic
            case another
        }
        let errors: [Error] = [
            CustomTestError.generic,
            CustomTestError.another,
            NSError(domain: "TestDomain", code: -1, userInfo: nil)
        ]

        for error in errors {
            XCTAssertEqual(error.secureDescription, "An unexpected error occurred. Please try again.")
        }
    }

    func testDecodingErrorSecureDescriptionDoesNotExposeNestedErrors() {
        enum CustomTestError: Error {
            case sensitive
        }

        let errors: [ScrutinyClientError] = [
            .decoding(CustomTestError.sensitive),
            .decoding(NSError(domain: "SensitiveDomain", code: 42))
        ]

        for error in errors {
            XCTAssertEqual(error.secureDescription, "Could not read the Scrutiny response. The server returned an unexpected format.")
        }
    }
}
