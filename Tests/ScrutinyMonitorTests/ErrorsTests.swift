import XCTest
@testable import ScrutinyMonitor

final class ErrorsTests: XCTestCase {

    func testInstallationValidationErrorDescription() {
        XCTAssertEqual(InstallationValidationError.emptyURL.errorDescription, "Enter the Scrutiny server URL.")
        XCTAssertEqual(InstallationValidationError.invalidURL.errorDescription, "Enter a valid URL such as http://nas.local:8080.")
        XCTAssertEqual(InstallationValidationError.insecureURL.errorDescription, "Public servers must use HTTPS.")
        XCTAssertEqual(InstallationValidationError.unsupportedScheme.errorDescription, "Scrutiny servers must use HTTP or HTTPS.")
        XCTAssertEqual(InstallationValidationError.invalidInput("Test message").errorDescription, "Test message")
    }

    func testSettingsSyncErrorDescription() {
        XCTAssertEqual(SettingsSyncError.providerNotConfigured(.webDAV).errorDescription, "WebDAV is not configured.")
        XCTAssertEqual(SettingsSyncError.providerNotConfigured(.iCloud).errorDescription, "iCloud is not configured.")
        XCTAssertEqual(SettingsSyncError.providerNotConfigured(.selectFolder).errorDescription, "Select a folder is not configured.")
        XCTAssertEqual(SettingsSyncError.invalidWebDAVURL.errorDescription, "Enter a valid WebDAV folder URL.")
        XCTAssertEqual(SettingsSyncError.insecureWebDAVURL.errorDescription, "Public WebDAV servers must use HTTPS.")
        XCTAssertEqual(SettingsSyncError.serverRejectedRequest(404).errorDescription, "The sync server returned HTTP 404.")
        XCTAssertEqual(SettingsSyncError.missingHTTPResponse.errorDescription, "The sync server returned an invalid response.")
    }

    func testScrutinyClientErrorDescription() {
        XCTAssertEqual(ScrutinyClientError.invalidResponse.errorDescription, "The server returned an invalid response.")
        XCTAssertEqual(ScrutinyClientError.httpStatus(500).errorDescription, "The server returned HTTP 500.")
        XCTAssertEqual(ScrutinyClientError.api("Server overload").errorDescription, "Server overload")
        XCTAssertEqual(ScrutinyClientError.decoding(URLError(.badURL)).errorDescription, "Could not read the Scrutiny response. The server returned an unexpected format.")
    }
}
