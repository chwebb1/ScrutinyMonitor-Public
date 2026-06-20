import XCTest
@testable import ScrutinyMonitor

final class InstallationPersistenceTests: XCTestCase {
    var userDefaults: UserDefaults!
    var sut: InstallationPersistence!
    let testSuiteName = "com.scrutinymonitor.tests.installationpersistence"
    let keychainService = InstallationPersistence.installationsKey

    override func setUp() {
        super.setUp()
        // Use a clean custom UserDefaults suite for each test
        userDefaults = UserDefaults(suiteName: testSuiteName)
        userDefaults.removePersistentDomain(forName: testSuiteName)

        sut = InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false)
    }

    override func tearDown() {
        // Clean up UserDefaults
        userDefaults.removePersistentDomain(forName: testSuiteName)

        KeychainHelper.resetTestState()
        super.tearDown()
    }

    func testLoadEmpty() {
        let loaded = sut.load()
        XCTAssertTrue(loaded.isEmpty, "Loading from empty UserDefaults should return an empty array")
    }

    func testSaveAndLoad() async {
        let testId = UUID()
        let testToken = "test-token-123"
        let installation = ScrutinyInstallation(
            id: testId,
            name: "Test Server",
            baseURL: URL(string: "https://test.scrutiny.local")!,
            apiToken: testToken.data(using: .utf8)!
        )

        // Ensure clean keychain state
        KeychainHelper.shared.delete(service: keychainService, account: testId.uuidString)

        // Save
        sut.save([installation])
        await waitForKeychainToken(testToken, account: testId.uuidString)

        // Load
        let loaded = sut.load()

        XCTAssertEqual(loaded.count, 1)
        if let first = loaded.first {
            XCTAssertEqual(first.id, testId)
            XCTAssertEqual(first.name, "Test Server")
            XCTAssertEqual(first.baseURL, URL(string: "https://test.scrutiny.local")!)
            XCTAssertEqual(first.apiToken, testToken.data(using: .utf8)!, "API Token should be correctly loaded from Keychain")
        }

        // Verify it was actually saved to keychain
        let keychainToken = KeychainHelper.shared.readData(service: keychainService, account: testId.uuidString)
        XCTAssertEqual(keychainToken, testToken.data(using: .utf8)!)

        // Clean up keychain
        KeychainHelper.shared.delete(service: keychainService, account: testId.uuidString)
    }

    func testMigrationFromUserDefaultsToKeychain() async throws {
        let testId = UUID()
        let legacyToken = "legacy-token-456"

        // Create raw JSON that simulates legacy structure where token is in UserDefaults
        let jsonString = """
        [
            {
                "id": "\(testId.uuidString)",
                "name": "Legacy Server",
                "baseURL": "https://legacy.scrutiny.local",
                "apiToken": "\(legacyToken)"
            }
        ]
        """
        let data = jsonString.data(using: .utf8)!
        userDefaults.set(data, forKey: InstallationPersistence.installationsKey)

        // Ensure clean keychain state before load
        KeychainHelper.shared.delete(service: keychainService, account: testId.uuidString)

        // Load (this should trigger migration)
        let loaded = sut.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.apiToken, legacyToken.data(using: .utf8)!, "Token should be correctly migrated and loaded")

        // Verify it is now in the keychain asynchronously since save() happens in a background task
        await waitForKeychainToken(legacyToken, account: testId.uuidString)

        // Clean up keychain
        KeychainHelper.shared.delete(service: keychainService, account: testId.uuidString)
    }

    func testSaveEmptyTokenDeletesFromKeychain() async {
        let testId = UUID()
        let testToken = "to-be-deleted-token"

        // Pre-populate keychain with a token
        KeychainHelper.shared.saveData(testToken.data(using: .utf8)!, service: keychainService, account: testId.uuidString)

        // Verify it's there
        XCTAssertEqual(KeychainHelper.shared.readData(service: keychainService, account: testId.uuidString), testToken.data(using: .utf8)!)

        // Save installation with empty token
        let installation = ScrutinyInstallation(
            id: testId,
            name: "Empty Token Server",
            baseURL: URL(string: "https://empty.scrutiny.local")!,
            apiToken: Data()
        )
        sut.save([installation])
        await waitForKeychainToken(nil, account: testId.uuidString)

        // Verify it's deleted from keychain
        let readToken = KeychainHelper.shared.readData(service: keychainService, account: testId.uuidString)
        XCTAssertNil(readToken, "Saving with an empty token should delete the existing token from Keychain")
    }

    func testDeleteToken() {
        let testId = UUID()
        let testToken = "token-to-delete"

        // Pre-populate keychain
        KeychainHelper.shared.saveData(testToken.data(using: .utf8)!, service: keychainService, account: testId.uuidString)

        // Verify it's there
        XCTAssertEqual(KeychainHelper.shared.readData(service: keychainService, account: testId.uuidString), testToken.data(using: .utf8)!)

        // Delete using sut
        sut.deleteToken(for: testId)

        // Verify it's deleted
        let readToken = KeychainHelper.shared.readData(service: keychainService, account: testId.uuidString)
        XCTAssertNil(readToken, "deleteToken should successfully remove the token from Keychain")
    }

    func testDeleteTokensEmpty() async {
        // Pre-populate keychain to verify it is untouched
        let testId = UUID()
        let testToken = "token-should-not-be-deleted"
        KeychainHelper.shared.saveData(testToken.data(using: .utf8)!, service: keychainService, account: testId.uuidString)

        // Delete with empty sequence
        sut.deleteTokens(for: [UUID]())

        // Verify token still exists
        let readToken = KeychainHelper.shared.readData(service: keychainService, account: testId.uuidString)
        XCTAssertEqual(readToken, testToken.data(using: .utf8)!, "Empty token deletion should not delete existing keychain items")

        // Clean up
        KeychainHelper.shared.delete(service: keychainService, account: testId.uuidString)
    }

    func testDeleteTokens() async {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let token1 = "token-1"
        let token2 = "token-2"
        let token3 = "token-3"

        // Pre-populate keychain
        KeychainHelper.shared.saveData(token1.data(using: .utf8)!, service: keychainService, account: id1.uuidString)
        KeychainHelper.shared.saveData(token2.data(using: .utf8)!, service: keychainService, account: id2.uuidString)
        KeychainHelper.shared.saveData(token3.data(using: .utf8)!, service: keychainService, account: id3.uuidString)

        // Delete using sut for id1 and id2
        sut.deleteTokens(for: [id1, id2])

        // Wait for asynchronous deletion
        await waitForKeychainToken(nil, account: id1.uuidString)
        await waitForKeychainToken(nil, account: id2.uuidString)

        // Verify id1 and id2 are deleted
        XCTAssertNil(KeychainHelper.shared.readData(service: keychainService, account: id1.uuidString))
        XCTAssertNil(KeychainHelper.shared.readData(service: keychainService, account: id2.uuidString))

        // Verify id3 is still present
        XCTAssertEqual(KeychainHelper.shared.readData(service: keychainService, account: id3.uuidString), token3.data(using: .utf8)!)

        // Clean up
        KeychainHelper.shared.delete(service: keychainService, account: id3.uuidString)
    }

    private func waitForKeychainToken(
        _ expectedToken: String?,
        account: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<50 {
            if KeychainHelper.shared.readData(service: keychainService, account: account) == expectedToken?.data(using: .utf8) {
                return
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(
            KeychainHelper.shared.readData(service: keychainService, account: account),
            expectedToken?.data(using: .utf8),
            file: file,
            line: line
        )
    }
}
