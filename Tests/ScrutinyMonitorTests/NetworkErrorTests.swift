import XCTest
@testable import ScrutinyMonitor

final class NetworkErrorTests: XCTestCase {
    func testTransientNetworkErrors() {
        let transientCodes: [URLError.Code] = [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
            .timedOut,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed
        ]

        for code in transientCodes {
            let error = URLError(code)
            XCTAssertTrue(error.isTransientNetworkError, "Expected \(code) to be considered a transient network error")
        }
    }

    func testNonTransientURLErrors() {
        let nonTransientCodes: [URLError.Code] = [
            .badServerResponse,
            .badURL,
            .unsupportedURL,
            .fileDoesNotExist,
            .noPermissionsToReadFile,
            .secureConnectionFailed,
            .serverCertificateHasBadDate,
            .serverCertificateUntrusted,
            .serverCertificateHasUnknownRoot,
            .serverCertificateNotYetValid,
            .clientCertificateRejected,
            .clientCertificateRequired,
            .cannotLoadFromNetwork,
            .cannotCreateFile,
            .cannotOpenFile,
            .cannotCloseFile,
            .cannotWriteToFile,
            .cannotRemoveFile,
            .cannotMoveFile,
            .downloadDecodingFailedMidStream,
            .downloadDecodingFailedToComplete
        ]

        for code in nonTransientCodes {
            let error = URLError(code)
            XCTAssertFalse(error.isTransientNetworkError, "Expected \(code) to NOT be considered a transient network error")
        }
    }

    func testNonURLErrors() {
        enum CustomError: Error {
            case unknown
            case notURLError
        }

        let error1 = CustomError.unknown
        let error2 = CustomError.notURLError
        let error3 = NSError(domain: "com.example.error", code: 1234, userInfo: nil)

        XCTAssertFalse(error1.isTransientNetworkError, "Expected CustomError.unknown to NOT be considered a transient network error")
        XCTAssertFalse(error2.isTransientNetworkError, "Expected CustomError.notURLError to NOT be considered a transient network error")
        XCTAssertFalse(error3.isTransientNetworkError, "Expected NSError to NOT be considered a transient network error")
    }
}
