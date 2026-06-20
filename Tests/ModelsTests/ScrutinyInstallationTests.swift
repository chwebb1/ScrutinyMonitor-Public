import XCTest
@testable import ScrutinyMonitor

final class ScrutinyInstallationTests: XCTestCase {

    // MARK: - encode() tests

    func testEncodeOmitsApiToken() throws {
        let installation = ScrutinyInstallation(
            id: UUID(),
            name: "Test Installation",
            baseURL: URL(string: "http://example.com")!,
            apiToken: "super-secret-token".data(using: .utf8)!,
            lastSnapshot: nil,
            lastRefreshDate: nil,
            lastError: nil,
            isRefreshing: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(installation)

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        XCTAssertNotNil(jsonObject)
        guard let jsonObject = jsonObject else { return }

        XCTAssertEqual(jsonObject["id"] as? String, installation.id.uuidString)
        XCTAssertEqual(jsonObject["name"] as? String, installation.name)
        XCTAssertEqual(jsonObject["baseURL"] as? String, installation.baseURL.absoluteString)

        // Assert that apiToken is explicitly NOT encoded for security
        XCTAssertNil(jsonObject["apiToken"])
    }

    // MARK: - decode() tests

    func testDecodeWithLegacyApiToken() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Legacy Installation",
            "baseURL": "http://legacy.example.com",
            "apiToken": "legacy-token"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let installation = try decoder.decode(ScrutinyInstallation.self, from: data)

        XCTAssertEqual(installation.id.uuidString, "123E4567-E89B-12D3-A456-426614174000")
        XCTAssertEqual(installation.name, "Legacy Installation")
        XCTAssertEqual(installation.baseURL.absoluteString, "http://legacy.example.com")
        XCTAssertEqual(installation.apiToken, "legacy-token".data(using: .utf8)!) // Token should be extracted
    }

    func testDecodeWithoutApiToken() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Modern Installation",
            "baseURL": "http://modern.example.com"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let installation = try decoder.decode(ScrutinyInstallation.self, from: data)

        XCTAssertEqual(installation.id.uuidString, "123E4567-E89B-12D3-A456-426614174000")
        XCTAssertEqual(installation.name, "Modern Installation")
        XCTAssertEqual(installation.baseURL.absoluteString, "http://modern.example.com")
        XCTAssertEqual(installation.apiToken, Data()) // Default when missing
    }

    func testDecodeWithEmptyApiToken() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Empty Token Installation",
            "baseURL": "http://empty.example.com",
            "apiToken": ""
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let installation = try decoder.decode(ScrutinyInstallation.self, from: data)

        XCTAssertEqual(installation.id.uuidString, "123E4567-E89B-12D3-A456-426614174000")
        XCTAssertEqual(installation.name, "Empty Token Installation")
        XCTAssertEqual(installation.baseURL.absoluteString, "http://empty.example.com")
        XCTAssertEqual(installation.apiToken, Data()) // Empty token remains empty
    }

    func testDecodeWithDataToken() throws {
        let tokenData = Data("data-token".utf8)
        let tokenString = tokenData.base64EncodedString()
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Data",
            "baseURL": "http://data.local",
            "apiToken": "\(tokenString)"
        }
        """

        let decoder = JSONDecoder()
        let installation = try decoder.decode(ScrutinyInstallation.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(installation.apiToken, tokenData)
    }

    func testDecodeWithBase64ValidLegacyToken() throws {
        // Base64-looking legacy values are preserved when base64 decoding produces non-text bytes.
        let legacyToken = "a1b2c3d4"
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Legacy with base64-valid chars",
            "baseURL": "http://legacy.example.com",
            "apiToken": "\(legacyToken)"
        }
        """

        let decoder = JSONDecoder()
        let installation = try decoder.decode(ScrutinyInstallation.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(installation.apiToken, legacyToken.data(using: .utf8)!)
        XCTAssertNotEqual(installation.apiToken, Data(base64Encoded: legacyToken))
    }

    // MARK: - Core Logic Tests

    func testBaseURLDidSetUpdatesHostText() {
        var installation = ScrutinyInstallation(name: "Test", baseURL: URL(string: "http://example.com:8080/api")!)
        XCTAssertEqual(installation.hostText, "example.com")

        installation.baseURL = URL(string: "https://newdomain.org/path")!
        XCTAssertEqual(installation.hostText, "newdomain.org")

        // No host URL
        installation.baseURL = URL(string: "file:///local/path")!
        XCTAssertEqual(installation.hostText, "file:///local/path")
    }

    func testStatusIsUnknownInitially() {
        let installation = ScrutinyInstallation(name: "Test", baseURL: URL(string: "http://localhost")!)
        XCTAssertEqual(installation.status, .unknown)
    }

    func testStatusIsRefreshingTakesPrecedence() {
        var installation = ScrutinyInstallation(name: "Test", baseURL: URL(string: "http://localhost")!)
        installation.isRefreshing = true
        installation.lastError = "Some error"

        let snapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 1, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: Date(timeIntervalSince1970: 0))
        installation.lastSnapshot = snapshot

        XCTAssertEqual(installation.status, .refreshing)
    }

    func testStatusIsOfflineWhenErrorOccurs() {
        var installation = ScrutinyInstallation(name: "Test", baseURL: URL(string: "http://localhost")!)
        installation.isRefreshing = false
        installation.lastError = "Some error"

        let snapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 1, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: Date(timeIntervalSince1970: 0))
        installation.lastSnapshot = snapshot

        XCTAssertEqual(installation.status, .offline)
    }

    func testStatusReflectsSnapshot() {
        var installation = ScrutinyInstallation(name: "Test", baseURL: URL(string: "http://localhost")!)
        installation.isRefreshing = false
        installation.lastError = nil

        let snapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 1, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: Date(timeIntervalSince1970: 0))
        installation.lastSnapshot = snapshot

        XCTAssertEqual(installation.status, .warning)
    }

    // MARK: - InstallationStatus enum tests

    func testInstallationStatusProperties() {
        let allStatuses = InstallationStatus.allCases
        for status in allStatuses {
            XCTAssertFalse(status.label.isEmpty)
            XCTAssertFalse(status.symbolName.isEmpty)
            _ = status.color // Just verify it doesn't crash
        }

        XCTAssertEqual(InstallationStatus.healthy.color, .green)
        XCTAssertEqual(InstallationStatus.warning.color, .yellow)
        XCTAssertEqual(InstallationStatus.critical.color, .red)
        XCTAssertEqual(InstallationStatus.offline.color, .red)
        XCTAssertEqual(InstallationStatus.refreshing.color, .blue)
        XCTAssertEqual(InstallationStatus.empty.color, .secondary)
        XCTAssertEqual(InstallationStatus.unknown.color, .secondary)
    }
}
