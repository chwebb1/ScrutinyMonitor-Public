import XCTest
@testable import ScrutinyMonitor

final class MonitorStoreTests: XCTestCase {
    var store: MonitorStore!
    var userDefaults: UserDefaults!
    let testSuiteName = "com.scrutinymonitor.tests.monitorstore"
    let referenceDate = Date(timeIntervalSince1970: 0)

    @MainActor
    override func setUp() {
        super.setUp()
        KeychainHelper.resetTestState()
        userDefaults = UserDefaults(suiteName: testSuiteName)
        userDefaults.removePersistentDomain(forName: testSuiteName)
        userDefaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)
        InstallationPersistence.resetCacheForTesting()

        let persistence = InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false)
        let cloudSync = CloudSettingsSynchronizer(defaults: userDefaults)
        let notificationService = DriveFailureNotificationService(defaults: userDefaults)

        // We initialize with default other parameters since we are mostly testing
        // input validation, addition, and removal logic, rather than network fetch logic.
        store = MonitorStore(
            client: .shared,
            persistence: persistence,
            cloudSync: cloudSync,
            notificationService: notificationService
        )
    }

    @MainActor
    override func tearDown() {
        MockURLProtocol.reset()
        userDefaults.removePersistentDomain(forName: testSuiteName)
        InstallationPersistence.resetCacheForTesting()
        // Clean up any test keychain items by attempting to delete keys we might have created
        for installation in store.installations {
            KeychainHelper.shared.delete(service: InstallationPersistence.installationsKey, account: installation.id.uuidString)
        }
        store = nil
        userDefaults = nil
        super.tearDown()
    }

    @MainActor
    func testAddInstallationSuccess() throws {
        XCTAssertTrue(store.installations.isEmpty)

        try store.addInstallation(
            name: "Test NAS",
            baseURLString: "http://testnas.local:8080",
            apiToken: "test-token-123"
        )

        XCTAssertEqual(store.installations.count, 1)
        let added = store.installations.first!
        XCTAssertEqual(added.name, "Test NAS")
        XCTAssertEqual(added.baseURL.absoluteString, "http://testnas.local:8080")
        XCTAssertEqual(added.apiToken, "test-token-123".data(using: .utf8)!)

        // Check selection was updated
        XCTAssertEqual(store.selection, .installation(added.id))

        // Verify keychain
        let keychainToken = KeychainHelper.shared.readData(
            service: InstallationPersistence.installationsKey,
            account: added.id.uuidString
        )
        XCTAssertEqual(keychainToken, "test-token-123".data(using: .utf8)!)
    }

    @MainActor
    func testAddInstallationTrimsWhitespace() throws {
        try store.addInstallation(
            name: "   Trimmed NAS   ",
            baseURLString: " \t\n http://trimmed.local:8080 \n\t ",
            apiToken: " \t trimmed-token \n "
        )

        XCTAssertEqual(store.installations.count, 1)
        let added = store.installations.first!
        XCTAssertEqual(added.name, "Trimmed NAS")
        XCTAssertEqual(added.baseURL.absoluteString, "http://trimmed.local:8080")
        XCTAssertEqual(added.apiToken, "trimmed-token".data(using: .utf8)!)
    }

    @MainActor
    func testAddInstallationEmptyNameDefaultsToHost() throws {
        try store.addInstallation(
            name: "   ",
            baseURLString: "http://unnamed.local:8080",
            apiToken: "token"
        )

        XCTAssertEqual(store.installations.count, 1)
        let added = store.installations.first!
        XCTAssertEqual(added.name, "unnamed.local")
    }

    @MainActor
    func testAddInstallationInvalidInputs() throws {
        // Empty URL
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }

        // Whitespace-only URL
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "   ", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "\t\t", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "\n\n", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: " \t\n ", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }

        // Invalid URL Scheme
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "ftp://nas.local", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .unsupportedScheme)
        }

        // Name too long
        let longName = String(repeating: "a", count: 101)
        XCTAssertThrowsError(try store.addInstallation(name: longName, baseURLString: "http://nas.local", apiToken: "")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "Name must be 100 characters or less.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // URL too long
        let longURL = "http://nas.local/" + String(repeating: "a", count: 1025)
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: longURL, apiToken: "")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "URL must be 1024 characters or less.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Control characters in token
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "http://nas.local", apiToken: "tok\nen")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "API token contains invalid characters.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Token too long
        let longToken = String(repeating: "a", count: 4097)
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "http://nas.local", apiToken: longToken)) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "API token must be 4096 characters or less.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Control characters in name
        XCTAssertThrowsError(try store.addInstallation(name: "Test\n\r", baseURLString: "http://nas.local", apiToken: "")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "Name contains invalid characters.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Control characters in URL
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "http://nas.local/path\n\rnext", apiToken: "")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "URL contains invalid characters.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Insecure URL (public HTTP)
        XCTAssertThrowsError(try store.addInstallation(name: "Test", baseURLString: "http://example.com", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .insecureURL)
        }

        // Allowed local HTTP URLs
        let localHTTPs = [
            "http://10.0.0.1", "http://192.168.1.100", "http://172.16.5.5", "http://127.0.0.1",
            "http://[::1]", "http://[fd00::1]",
            "http://localhost", "http://nas", "http://nas.local:8080"
        ]

        for local in localHTTPs {
            // These should not throw validation errors (especially not insecureURL)
            XCTAssertNoThrow(try store.addInstallation(name: "Local Test", baseURLString: local, apiToken: ""))
            // Remove it right away so we don't clutter the store
            store.installations.removeLast()
        }
    }

    @MainActor
    func testAddInstallationStripsEmbeddedCredentials() throws {
        try store.addInstallation(
            name: "Test",
            baseURLString: "http://admin:password123@nas.local:8080",
            apiToken: "token"
        )

        XCTAssertEqual(store.installations.count, 1)
        let added = store.installations.first!
        XCTAssertEqual(added.baseURL.absoluteString, "http://nas.local:8080")
        XCTAssertNil(added.baseURL.user)
        XCTAssertNil(added.baseURL.password)
    }

    @MainActor
    func testUpdateInstallationSuccess() throws {
        try store.addInstallation(
            name: "Old NAS",
            baseURLString: "http://oldnas.local:8080",
            apiToken: "old-token"
        )

        let id = store.installations.first!.id

        try store.updateInstallation(
            id: id,
            name: "Updated NAS",
            baseURLString: "https://newnas.local",
            apiToken: "new-token"
        )

        XCTAssertEqual(store.installations.count, 1)
        let updated = store.installations.first!
        XCTAssertEqual(updated.name, "Updated NAS")
        XCTAssertEqual(updated.baseURL.absoluteString, "https://newnas.local")
        XCTAssertEqual(updated.apiToken, "new-token".data(using: .utf8)!)

        // Verify keychain was updated
        let keychainToken = KeychainHelper.shared.readData(
            service: InstallationPersistence.installationsKey,
            account: id.uuidString
        )
        XCTAssertEqual(keychainToken, "new-token".data(using: .utf8)!)
    }

    @MainActor
    func testUpdateInstallationClearsLastErrorAndUpdatesCorrectIndex() throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "token1")
        try store.addInstallation(name: "NAS 2", baseURLString: "http://nas2.local", apiToken: "token2")

        let id1 = store.installations[0].id
        let id2 = store.installations[1].id

        // Inject an error to verify it gets cleared
        store.installations[1].lastError = "Network timeout"

        try store.updateInstallation(
            id: id2,
            name: "Updated NAS 2",
            baseURLString: "http://updated.local",
            apiToken: "new-token2"
        )

        XCTAssertEqual(store.installations.count, 2)

        // Verify NAS 1 is completely untouched
        let nas1 = store.installations[0]
        XCTAssertEqual(nas1.id, id1)
        XCTAssertEqual(nas1.name, "NAS 1")
        XCTAssertEqual(nas1.baseURL.absoluteString, "http://nas1.local")
        XCTAssertEqual(nas1.apiToken, "token1".data(using: .utf8)!)

        // Verify NAS 2 is updated correctly
        let nas2 = store.installations[1]
        XCTAssertEqual(nas2.id, id2)
        XCTAssertEqual(nas2.name, "Updated NAS 2")
        XCTAssertEqual(nas2.baseURL.absoluteString, "http://updated.local")
        XCTAssertEqual(nas2.apiToken, "new-token2".data(using: .utf8)!)

        // Verify the error was cleared
        XCTAssertNil(nas2.lastError)
    }

    @MainActor
    func testUpdateInstallationNotFound() throws {
        try store.addInstallation(
            name: "Old NAS",
            baseURLString: "http://oldnas.local:8080",
            apiToken: "old-token"
        )

        let fakeId = UUID()

        try store.updateInstallation(
            id: fakeId,
            name: "Updated NAS",
            baseURLString: "https://newnas.local",
            apiToken: "new-token"
        )

        XCTAssertEqual(store.installations.count, 1)
        let unchanged = store.installations.first!
        XCTAssertEqual(unchanged.name, "Old NAS")
        XCTAssertEqual(unchanged.baseURL.absoluteString, "http://oldnas.local:8080")
        XCTAssertEqual(unchanged.apiToken, "old-token".data(using: .utf8)!)
    }

    @MainActor
    func testUpdateInstallationTrimsWhitespace() throws {
        try store.addInstallation(
            name: "Old NAS",
            baseURLString: "http://oldnas.local:8080",
            apiToken: "old-token"
        )

        let id = store.installations.first!.id

        try store.updateInstallation(
            id: id,
            name: "   Trimmed NAS   ",
            baseURLString: "   http://trimmed.local:8080   ",
            apiToken: "  trimmed-token  "
        )

        XCTAssertEqual(store.installations.count, 1)
        let updated = store.installations.first!
        XCTAssertEqual(updated.name, "Trimmed NAS")
        XCTAssertEqual(updated.baseURL.absoluteString, "http://trimmed.local:8080")
        XCTAssertEqual(updated.apiToken, "trimmed-token".data(using: .utf8)!)
    }

    @MainActor
    func testUpdateInstallationEmptyNameDefaultsToHost() throws {
        try store.addInstallation(
            name: "Old NAS",
            baseURLString: "http://oldnas.local:8080",
            apiToken: "old-token"
        )

        let id = store.installations.first!.id

        try store.updateInstallation(
            id: id,
            name: "   ",
            baseURLString: "http://unnamed.local:8080",
            apiToken: "token"
        )

        XCTAssertEqual(store.installations.count, 1)
        let updated = store.installations.first!
        XCTAssertEqual(updated.name, "unnamed.local")
    }

    @MainActor
    func testUpdateInstallationEmptyTokenDeletesFromKeychain() throws {
        try store.addInstallation(
            name: "Old NAS",
            baseURLString: "http://oldnas.local:8080",
            apiToken: "old-token"
        )

        let id = store.installations.first!.id

        // Verify initial token in keychain
        var keychainToken = KeychainHelper.shared.readData(
            service: InstallationPersistence.installationsKey,
            account: id.uuidString
        )
        XCTAssertEqual(keychainToken, "old-token".data(using: .utf8)!)

        try store.updateInstallation(
            id: id,
            name: "Updated NAS",
            baseURLString: "http://oldnas.local:8080",
            apiToken: "   " // Effectively empty after trimming
        )

        XCTAssertEqual(store.installations.count, 1)
        let updated = store.installations.first!
        XCTAssertEqual(updated.apiToken, Data())

        // Verify keychain was deleted
        keychainToken = KeychainHelper.shared.readData(
            service: InstallationPersistence.installationsKey,
            account: id.uuidString
        )
        XCTAssertNil(keychainToken)
    }

    @MainActor
    func testUpdateInstallationInvalidInputs() throws {
        try store.addInstallation(
            name: "Old NAS",
            baseURLString: "http://oldnas.local:8080",
            apiToken: "old-token"
        )

        let id = store.installations.first!.id

        // Empty URL
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }

        // Whitespace-only URL
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "   ", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "\t\t", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "\n\n", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: " \t\n ", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .emptyURL)
        }

        // Invalid URL Scheme
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "ftp://nas.local", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .unsupportedScheme)
        }

        // Name too long
        let longName = String(repeating: "a", count: 101)
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: longName, baseURLString: "http://nas.local", apiToken: "")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "Name must be 100 characters or less.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // URL too long
        let longURL = "http://nas.local/" + String(repeating: "a", count: 1025)
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: longURL, apiToken: "")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "URL must be 1024 characters or less.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Control characters in token
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "http://nas.local", apiToken: "tok\nen")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "API token contains invalid characters.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Token too long
        let longToken = String(repeating: "a", count: 4097)
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "http://nas.local", apiToken: longToken)) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "API token must be 4096 characters or less.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Control characters in name
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test\n\r", baseURLString: "http://nas.local", apiToken: "")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "Name contains invalid characters.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Control characters in URL
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "http://nas.local/path\n\rnext", apiToken: "")) { error in
            if case .invalidInput(let message) = error as? InstallationValidationError {
                XCTAssertEqual(message, "URL contains invalid characters.")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }

        // Insecure URL (public HTTP) on update
        XCTAssertThrowsError(try store.updateInstallation(id: id, name: "Test", baseURLString: "http://example.com", apiToken: "")) { error in
            XCTAssertEqual(error as? InstallationValidationError, .insecureURL)
        }
    }

    @MainActor
    func testRemoveSelectedInstallation_FallbacksToOverviewWhenMultipleRemain() async throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "token1")
        try store.addInstallation(name: "NAS 2", baseURLString: "http://nas2.local", apiToken: "token2")
        try store.addInstallation(name: "NAS 3", baseURLString: "http://nas3.local", apiToken: "token3")

        XCTAssertEqual(store.installations.count, 3, "Precondition: Expected 3 installations to be successfully added.")
        let id1 = store.installations[0].id
        let id2 = store.installations[1].id
        let id3 = store.installations[2].id
        store.selection = .installation(id2)

        await store.removeSelectedInstallation()?.value

        XCTAssertEqual(store.installations.count, 2)
        XCTAssertEqual(store.selection, .overview)
        XCTAssertNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id2.uuidString))
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id1.uuidString))
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id3.uuidString))
    }

    @MainActor
    func testRemoveSelectedInstallation_RemovesFirstInstallationFallbacksToOverview() async throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "token1")
        try store.addInstallation(name: "NAS 2", baseURLString: "http://nas2.local", apiToken: "token2")
        try store.addInstallation(name: "NAS 3", baseURLString: "http://nas3.local", apiToken: "token3")

        XCTAssertEqual(store.installations.count, 3, "Precondition: Expected 3 installations to be successfully added.")
        let id1 = store.installations[0].id
        let id2 = store.installations[1].id
        let id3 = store.installations[2].id
        store.selection = .installation(id1)

        await store.removeSelectedInstallation()?.value

        XCTAssertEqual(store.installations.count, 2)
        XCTAssertEqual(store.selection, .overview)
        XCTAssertNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id1.uuidString))
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id2.uuidString))
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id3.uuidString))
    }

    @MainActor
    func testRemoveSelectedInstallation_FallbacksToOnlyRemainingInstallation() async throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "token1")
        try store.addInstallation(name: "NAS 2", baseURLString: "http://nas2.local", apiToken: "token2")

        XCTAssertEqual(store.installations.count, 2, "Precondition: Expected 2 installations to be successfully added.")
        let id1 = store.installations[0].id
        let id2 = store.installations[1].id
        store.selection = .installation(id2)

        await store.removeSelectedInstallation()?.value

        XCTAssertEqual(store.installations.count, 1)
        XCTAssertEqual(store.installations.first!.id, id1)
        XCTAssertEqual(store.selection, .installation(id1))
        XCTAssertNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id2.uuidString))
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id1.uuidString))
    }

    @MainActor
    func testRemoveSelectedInstallation_ClearsSelectionWhenNoneRemain() async throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "token1")

        XCTAssertEqual(store.installations.count, 1, "Precondition: Expected 1 installation to be successfully added.")
        let id1 = store.installations[0].id
        store.selection = .installation(id1)

        await store.removeSelectedInstallation()?.value

        XCTAssertEqual(store.installations.count, 0)
        XCTAssertNil(store.selection)
        XCTAssertNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id1.uuidString))
    }

    @MainActor
    func testRemoveSelectedInstallation_DoesNothingWhenOverviewSelected() async throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "token1")
        try store.addInstallation(name: "NAS 2", baseURLString: "http://nas2.local", apiToken: "token2")

        XCTAssertEqual(store.installations.count, 2, "Precondition: Expected 2 installations to be successfully added.")
        let id1 = store.installations[0].id
        let id2 = store.installations[1].id
        store.selection = .overview
        await store.removeSelectedInstallation()?.value

        XCTAssertEqual(store.installations.count, 2)
        XCTAssertEqual(store.selection, .overview)
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id1.uuidString))
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id2.uuidString))
    }

    @MainActor
    func testRemoveSelectedInstallation_DoesNothingWhenSelectionIsNil() async throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "token1")

        XCTAssertEqual(store.installations.count, 1, "Precondition: Expected 1 installation to be successfully added.")
        let id1 = store.installations[0].id
        store.selection = nil
        await store.removeSelectedInstallation()?.value

        XCTAssertEqual(store.installations.count, 1)
        XCTAssertNil(store.selection)
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id1.uuidString))
    }

    @MainActor
    func testRefreshSelectedSuccessPath() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockClient = ScrutinyClient(sessionConfiguration: config)

        let customStore = MonitorStore(
            client: mockClient,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "success": true,
                "data": { "summary": {} }
            }
            """.data(using: .utf8)!
            return (response, json)
        }

        try customStore.addInstallation(
            name: "Success NAS",
            baseURLString: "http://successnas.local",
            apiToken: "token"
        )

        guard let addedId = customStore.installations.first?.id else {
            XCTFail("Failed to add installation")
            return
        }

        customStore.selection = MonitorSelection.installation(addedId)

        await customStore.refreshSelected()

        guard let index = customStore.installations.firstIndex(where: { $0.id == addedId }) else {
            XCTFail("Installation missing")
            return
        }

        let refreshedInstallation = customStore.installations[index]
        XCTAssertFalse(refreshedInstallation.isRefreshing)
        XCTAssertNil(refreshedInstallation.lastError)
        XCTAssertNotNil(refreshedInstallation.lastSnapshot)
    }

    @MainActor
    func testRefreshSelectedErrorPath() async throws {
        // Setup mock networking
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockClient = ScrutinyClient(sessionConfiguration: config)

        let customStore = MonitorStore(
            client: mockClient,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        MockURLProtocol.requestHandler = { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (response, Data())
        }

        try customStore.addInstallation(
            name: "Error NAS",
            baseURLString: "http://errornas.local",
            apiToken: "token"
        )

        guard let addedId = customStore.installations.first?.id else {
            XCTFail("Failed to add installation")
            return
        }

        customStore.selection = MonitorSelection.installation(addedId)

        await customStore.refreshSelected()

        guard let index = customStore.installations.firstIndex(where: { $0.id == addedId }) else {
            XCTFail("Installation missing")
            return
        }

        let refreshedInstallation = customStore.installations[index]
        XCTAssertFalse(refreshedInstallation.isRefreshing)
        XCTAssertEqual(refreshedInstallation.lastError, ScrutinyClientError.invalidResponse.secureDescription)
    }

    @MainActor
    func testRefreshSelectedNetworkErrorPath() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockClient = ScrutinyClient(sessionConfiguration: config)

        let customStore = MonitorStore(
            client: mockClient,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        MockURLProtocol.requestHandler = { request in
            throw URLError(.notConnectedToInternet)
        }

        try customStore.addInstallation(
            name: "Network Error NAS",
            baseURLString: "http://errornas.local",
            apiToken: "token"
        )

        guard let addedId = customStore.installations.first?.id else {
            XCTFail("Failed to add installation")
            return
        }

        customStore.selection = MonitorSelection.installation(addedId)

        await customStore.refreshSelected()

        guard let index = customStore.installations.firstIndex(where: { $0.id == addedId }) else {
            XCTFail("Installation missing")
            return
        }

        let refreshedInstallation = customStore.installations[index]
        XCTAssertFalse(refreshedInstallation.isRefreshing)
        XCTAssertEqual(refreshedInstallation.lastError, URLError(.notConnectedToInternet).secureDescription)
    }

    @MainActor
    func testRefreshAllNetworkErrorPath() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockClient = ScrutinyClient(sessionConfiguration: config)

        let customStore = MonitorStore(
            client: mockClient,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        MockURLProtocol.requestHandler = { request in
            throw URLError(.notConnectedToInternet)
        }

        try customStore.addInstallation(name: "Network Error NAS 1", baseURLString: "http://errornas1.local", apiToken: "token")
        try customStore.addInstallation(name: "Network Error NAS 2", baseURLString: "http://errornas2.local", apiToken: "token")

        await customStore.refreshAll()

        for installation in customStore.installations {
            XCTAssertFalse(installation.isRefreshing)
            XCTAssertEqual(installation.lastError, URLError(.notConnectedToInternet).secureDescription)
        }
    }

    @MainActor
    func testApplyCloudInstallationChanges() async throws {
        userDefaults.set(SettingsSyncProvider.iCloud.rawValue, forKey: SettingsSyncDefaults.providerKey)

        let mockBackend = MockSettingsSyncBackend()
        let cloudSync = CloudSettingsSynchronizer(defaults: userDefaults)
        cloudSync.backend = mockBackend
        cloudSync.activeProvider = .iCloud

        let customStore = MonitorStore(
            client: .shared,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: cloudSync,
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        // Add a local installation bypassing `addInstallation` to avoid background sync race conditions
        let id2 = UUID()
        let localInstallation = ScrutinyInstallation(id: id2, name: "Local NAS", baseURL: URL(string: "http://local.local")!, apiToken: Data("token1".utf8))
        customStore.installations = [localInstallation]
        KeychainHelper.shared.saveData(Data("token1".utf8), service: InstallationPersistence.installationsKey, account: id2.uuidString)
        XCTAssertNotNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id2.uuidString))

        let id1 = UUID()
        let futureDate = Date().addingTimeInterval(10)
        let record = InstallationSyncRecord(
            id: id1,
            name: "Cloud NAS",
            baseURL: URL(string: "http://cloud.local")!,
            updatedAt: futureDate
        )

        // Simulating a deletion of the local one from the cloud
        let deletion = InstallationSyncDeletion(id: id2, deletedAt: futureDate)

        mockBackend.payloadToReturn = SettingsSyncPayload(
            version: 1,
            installations: InstallationSyncEnvelope(
                records: [record],
                deletions: [deletion],
                updatedAt: futureDate
            ),
            preferences: nil
        )

        cloudSync.installationsDidChange?()

        await waitUntil(timeout: 3.0) {
            customStore.installations.count == 1 && customStore.installations.first?.name == "Cloud NAS"
        }

        XCTAssertEqual(customStore.installations.count, 1)
        XCTAssertEqual(customStore.installations.first?.name, "Cloud NAS")
        XCTAssertEqual(customStore.selection, .installation(id1))

        // Verify the token for id2 was deleted
        XCTAssertNil(KeychainHelper.shared.readData(service: InstallationPersistence.installationsKey, account: id2.uuidString))
    }

    @MainActor
    func testApplyCloudInstallationChangesErrorPath() async throws {
        userDefaults.set(SettingsSyncProvider.iCloud.rawValue, forKey: SettingsSyncDefaults.providerKey)

        let mockBackend = MockSettingsSyncBackend()
        let cloudSync = CloudSettingsSynchronizer(defaults: userDefaults)
        cloudSync.backend = mockBackend
        cloudSync.activeProvider = .iCloud

        let customStore = MonitorStore(
            client: .shared,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: cloudSync,
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        // Add a local installation bypassing `addInstallation` to avoid background sync race conditions
        let id1 = UUID()
        let localInstallation = ScrutinyInstallation(id: id1, name: "Local NAS", baseURL: URL(string: "http://local.local")!, apiToken: Data("token1".utf8))
        customStore.installations = [localInstallation]
        KeychainHelper.shared.saveData(Data("token1".utf8), service: InstallationPersistence.installationsKey, account: id1.uuidString)

        // Mock backend to throw an error
        mockBackend.errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)

        let loadExpectation = expectation(description: "Wait for loadPayload")
        let lock = NSLock()
        var fulfilled = false
        mockBackend.onLoadPayload = {
            lock.lock()
            defer { lock.unlock() }
            if !fulfilled {
                loadExpectation.fulfill()
                fulfilled = true
            }
        }

        cloudSync.installationsDidChange?()

        await fulfillment(of: [loadExpectation], timeout: 3.0)

        // Verify the installations remain unchanged
        XCTAssertEqual(customStore.installations.count, 1)
        XCTAssertEqual(customStore.installations.first?.id, id1)
        XCTAssertEqual(customStore.installations.first?.name, "Local NAS")

        // Clean up
        KeychainHelper.shared.delete(service: InstallationPersistence.installationsKey, account: id1.uuidString)
    }

    @MainActor
    func testScheduleSaveDebounce() async throws {
        let mockDefaults = MockUserDefaults(suiteName: "com.scrutinymonitor.tests.debounce")!
        mockDefaults.removePersistentDomain(forName: "com.scrutinymonitor.tests.debounce")
        mockDefaults.set(SettingsSyncProvider.iCloud.rawValue, forKey: SettingsSyncDefaults.providerKey)

        let persistence = InstallationPersistence(userDefaults: mockDefaults, migratesLegacyDefaults: false)
        let cloudSync = CloudSettingsSynchronizer(defaults: mockDefaults)
        cloudSync.backend = MockSettingsSyncBackend()
        cloudSync.activeProvider = .iCloud
        let notificationService = DriveFailureNotificationService(defaults: mockDefaults)

        let customStore = MonitorStore(
            client: .shared,
            persistence: persistence,
            cloudSync: cloudSync,
            notificationService: notificationService
        )

        // Mutate the store 5 times rapidly
        for i in 1...5 {
            try customStore.addInstallation(
                name: "NAS \(i)",
                baseURLString: "http://nas\(i).local",
                apiToken: "token"
            )
        }

        // We mutated it 5 times. Since it debounces for 500ms, the write to UserDefaults should not have happened yet.
        XCTAssertEqual(mockDefaults.setCallCount, 0)

        await waitUntil(timeout: 2.0) {
            mockDefaults.setCallCount == 1
        }
        XCTAssertEqual(mockDefaults.setCallCount, 1)

        // Clean up keychain items we created
        for installation in customStore.installations {
            KeychainHelper.shared.delete(service: InstallationPersistence.installationsKey, account: installation.id.uuidString)
        }
    }

    @MainActor
    func testRefreshAllErrorPath() async throws {
        // Setup mock networking
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockClient = ScrutinyClient(sessionConfiguration: config)

        let customStore = MonitorStore(
            client: mockClient,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        MockURLProtocol.requestHandler = { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (response, Data())
        }

        try customStore.addInstallation(name: "Error NAS 1", baseURLString: "http://errornas1.local", apiToken: "token")
        try customStore.addInstallation(name: "Error NAS 2", baseURLString: "http://errornas2.local", apiToken: "token")

        await customStore.refreshAll()

        for installation in customStore.installations {
            XCTAssertFalse(installation.isRefreshing)
            XCTAssertEqual(installation.lastError, ScrutinyClientError.invalidResponse.secureDescription)
        }
    }

    @MainActor
    func testRefreshAllEmptySequence() async throws {
        defer { MockURLProtocol.requestHandler = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockClient = ScrutinyClient(sessionConfiguration: config)

        let customStore = MonitorStore(
            client: mockClient,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        MockURLProtocol.requestHandler = { request in
            XCTFail("Should not make network requests when installations are empty")
            throw URLError(.badURL)
        }

        XCTAssertTrue(customStore.installations.isEmpty)
        await customStore.refreshAll()
        XCTAssertTrue(customStore.installations.isEmpty)
    }

    @MainActor
    func testConcurrentRefreshAllStateTransitions() async throws {
        // Setup mock networking with artificial delay
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockClient = ScrutinyClient(sessionConfiguration: config)

        let customStore = MonitorStore(
            client: mockClient,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )

        // Add two installations
        try customStore.addInstallation(name: "Server 1", baseURLString: "http://server1.local", apiToken: "")
        try customStore.addInstallation(name: "Server 2", baseURLString: "http://server2.local", apiToken: "")

        let requestsStarted = expectation(description: "Refresh requests started")
        requestsStarted.expectedFulfillmentCount = 2
        let responseGate = AsyncGate()
        let requestCounter = AsyncRequestCounter()

        // Set up MockURLProtocol to pause responses while we inspect in-flight state.
        MockURLProtocol.asyncRequestHandler = { request in
            if await requestCounter.shouldFulfill(maxFulfillments: 2) {
                requestsStarted.fulfill()
            }

            await responseGate.wait()

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "success": true,
                "data": { "summary": {} }
            }
            """.data(using: .utf8)!
            return (response, json)
        }

        // Before refresh: not refreshing
        XCTAssertFalse(customStore.isRefreshing)
        XCTAssertFalse(customStore.installations[0].isRefreshing)
        XCTAssertFalse(customStore.installations[1].isRefreshing)

        // Trigger refreshAll as a background Task so we can inspect intermediate state while it is running!
        let refreshTask = Task {
            await customStore.refreshAll()
        }

        await fulfillment(of: [requestsStarted], timeout: 2.0)

        // Now they should be concurrently refreshing!
        XCTAssertTrue(customStore.isRefreshing)
        XCTAssertTrue(customStore.installations[0].isRefreshing)
        XCTAssertTrue(customStore.installations[1].isRefreshing)
        XCTAssertEqual(customStore.overallStatus, .refreshing)

        await responseGate.open()

        // Wait for the full refreshTask to finish
        _ = await refreshTask.result

        // After refresh: finished refreshing
        XCTAssertFalse(customStore.isRefreshing)
        XCTAssertFalse(customStore.installations[0].isRefreshing)
        XCTAssertFalse(customStore.installations[1].isRefreshing)
    }

    // To cleanly test aggregates without triggering background saves and test pollution,
    // we bypass `store.installations` mutation (which triggers `scheduleSave()`).
    // Instead, we inject the installations into UserDefaults and initialize a fresh store.
    @MainActor
    private func makeStoreWith(installations: [ScrutinyInstallation]) throws -> MonitorStore {
        let persistence = InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false)
        let encoder = JSONEncoder()

        // ScrutinyInstallation deliberately strips apiToken during encoding; keep
        // token-bearing test setup on the normal persistence path instead.
        let data = try encoder.encode(installations)
        userDefaults.set(data, forKey: InstallationPersistence.installationsKey)
        InstallationPersistence.resetCacheForTesting()

        store = MonitorStore(
            client: .shared,
            persistence: persistence,
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )
        return store
    }

    private func makeAggregateInstallation(name: String, host: String) -> ScrutinyInstallation {
        ScrutinyInstallation(id: UUID(), name: name, baseURL: URL(string: "http://\(host).local")!, apiToken: Data())
    }

    @MainActor
    func testOverallStatusEmpty() throws {
        let store = try makeStoreWith(installations: [])
        XCTAssertEqual(store.overviewDriveCount, 0)
        XCTAssertFalse(store.overviewHasIssues)
        XCTAssertEqual(store.overallStatus, .empty)
    }

    @MainActor
    func testOverallStatusHealthy() throws {
        let healthySnapshot = InstallationSnapshot(healthOK: true, totalDrives: 4, healthyDrives: 4, warningDrives: 0, criticalDrives: 0, devices: [], collectedAt: referenceDate)
        var inst1 = makeAggregateInstallation(name: "NAS1", host: "nas1")
        inst1.lastSnapshot = healthySnapshot

        let store = try makeStoreWith(installations: [inst1])
        XCTAssertEqual(store.overviewDriveCount, 4)
        XCTAssertFalse(store.overviewHasIssues)
        XCTAssertEqual(store.overallStatus, .healthy)
    }

    @MainActor
    func testOverallStatusCriticalTakesPrecedenceOverWarningAndOffline() throws {
        // healthOK means the Scrutiny API responded; drive warning/critical counts
        // determine degraded drive-health status when the installation is online.
        let warningSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 1, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: referenceDate)
        var instWarning = makeAggregateInstallation(name: "NAS2", host: "nas2")
        instWarning.lastSnapshot = warningSnapshot

        let criticalSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 0, warningDrives: 0, criticalDrives: 1, devices: [], collectedAt: referenceDate)
        var instCritical = makeAggregateInstallation(name: "NAS3", host: "nas3")
        instCritical.lastSnapshot = criticalSnapshot

        var instOffline = makeAggregateInstallation(name: "NAS4", host: "nas4")
        instOffline.lastSnapshot = nil
        instOffline.lastError = "Connection timeout"

        let store = try makeStoreWith(installations: [instWarning, instCritical, instOffline])

        XCTAssertEqual(store.overviewDriveCount, 3)
        XCTAssertTrue(store.overviewHasIssues)
        XCTAssertEqual(store.overallStatus, .critical)
    }

    @MainActor
    func testOverallStatusWarningTakesPrecedenceOverOffline() throws {
        let warningSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 1, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: referenceDate)
        var instWarning = makeAggregateInstallation(name: "NAS2", host: "nas2")
        instWarning.lastSnapshot = warningSnapshot

        var instOffline = makeAggregateInstallation(name: "NAS4", host: "nas4")
        instOffline.lastSnapshot = nil
        instOffline.lastError = "Connection timeout"

        let store = try makeStoreWith(installations: [instWarning, instOffline])

        XCTAssertEqual(store.overviewDriveCount, 2)
        XCTAssertTrue(store.overviewHasIssues)
        XCTAssertEqual(store.overallStatus, .warning)
    }

    @MainActor
    func testOverallStatusOfflineWhenAllInstallationsOffline() throws {
        var firstOffline = makeAggregateInstallation(name: "NAS1", host: "nas1")
        firstOffline.lastSnapshot = nil
        firstOffline.lastError = "Connection timeout"

        var secondOffline = makeAggregateInstallation(name: "NAS2", host: "nas2")
        secondOffline.lastSnapshot = nil
        secondOffline.lastError = "Connection refused"

        let store = try makeStoreWith(installations: [firstOffline, secondOffline])

        XCTAssertEqual(store.overviewDriveCount, 0)
        XCTAssertTrue(store.overviewHasIssues)
        XCTAssertEqual(store.overallStatus, .offline)
    }

    @MainActor
    func testOverallStatusOfflineTakesPrecedenceOverHealthy() throws {
        let healthySnapshot = InstallationSnapshot(healthOK: true, totalDrives: 4, healthyDrives: 4, warningDrives: 0, criticalDrives: 0, devices: [], collectedAt: referenceDate)
        var healthyInstallation = makeAggregateInstallation(name: "NAS1", host: "nas1")
        healthyInstallation.lastSnapshot = healthySnapshot

        var offlineInstallation = makeAggregateInstallation(name: "NAS2", host: "nas2")
        offlineInstallation.lastSnapshot = nil
        offlineInstallation.lastError = "Connection timeout"

        let store = try makeStoreWith(installations: [healthyInstallation, offlineInstallation])

        XCTAssertEqual(store.overviewDriveCount, 4)
        XCTAssertTrue(store.overviewHasIssues)
        XCTAssertEqual(store.overallStatus, .offline)
    }

    @MainActor
    func testDetermineOverallStatusPriority_Empty() throws {
        XCTAssertEqual(store.overallStatus, .empty)
    }

    @MainActor
    func testDetermineOverallStatusPriority_InstallationsWithoutStatus() throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "")
        try store.addInstallation(name: "NAS 2", baseURLString: "http://nas2.local", apiToken: "")

        // State without snapshots is .unknown for each installation.
        // `updateAggregates` checks `hasCritical`, `hasWarning`, `hasOffline`.
        // `unknown` doesn't trigger any of those, so it falls back to `.healthy`.
        XCTAssertEqual(store.overallStatus, .healthy)
    }

    @MainActor
    func testDetermineOverallStatusPriority_Refreshing() throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "")
        store.installations[0].lastError = nil
        store.installations[0].isRefreshing = true
        XCTAssertEqual(store.overallStatus, .refreshing)
    }

    @MainActor
    func testDetermineOverallStatusPriority_Offline() throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "")
        store.installations[0].isRefreshing = false
        store.installations[0].lastError = "Connection failed"
        XCTAssertEqual(store.overallStatus, .offline)
    }

    @MainActor
    func testDetermineOverallStatusPriority_Warning() throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "")
        store.installations[0].lastError = nil
        store.installations[0].isRefreshing = false
        store.installations[0].lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 0, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: Date())
        XCTAssertEqual(store.overallStatus, .warning)
    }

    @MainActor
    func testDetermineOverallStatusPriority_Critical() throws {
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "")
        store.installations[0].lastError = nil
        store.installations[0].isRefreshing = false
        store.installations[0].lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 0, warningDrives: 0, criticalDrives: 1, devices: [], collectedAt: Date())
        XCTAssertEqual(store.overallStatus, .critical)
    }

    @MainActor
    func testDetermineOverallStatusPriority_CriticalOverridesOthers() throws {
        // Priority chain: critical > warning > offline > refreshing > healthy > empty
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "")
        try store.addInstallation(name: "NAS 2", baseURLString: "http://nas2.local", apiToken: "")
        try store.addInstallation(name: "NAS 3", baseURLString: "http://nas3.local", apiToken: "")

        store.installations[0].lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 0, warningDrives: 0, criticalDrives: 1, devices: [], collectedAt: Date())

        store.installations[1].lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 0, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: Date())

        store.installations[2].lastError = "Offline"
        store.installations[2].isRefreshing = true
        XCTAssertEqual(store.overallStatus, .critical)
    }

    @MainActor
    func testDetermineOverallStatusPriority_MixedStatesWithoutCritical() throws {
        // Priority chain: critical > warning > offline > refreshing > healthy > empty
        try store.addInstallation(name: "NAS 1", baseURLString: "http://nas1.local", apiToken: "")
        try store.addInstallation(name: "NAS 2", baseURLString: "http://nas2.local", apiToken: "")
        try store.addInstallation(name: "NAS 3", baseURLString: "http://nas3.local", apiToken: "")

        store.installations[0].lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 0, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: Date())

        store.installations[1].lastError = "Offline"
        store.installations[1].isRefreshing = false

        store.installations[2].isRefreshing = true
        store.installations[2].lastError = nil

        // Warning should win over offline and refreshing
        XCTAssertEqual(store.overallStatus, .warning)
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval,
        intervalNanoseconds: UInt64 = 20_000_000,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }

            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }

        XCTAssertTrue(condition(), "Timed out waiting for condition", file: file, line: line)
    }
}

actor AsyncGate {
    private var isOpen = false
    private var waiters = [CheckedContinuation<Void, Never>]()

    func wait() async {
        if isOpen {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let currentWaiters = waiters
        waiters.removeAll()
        for waiter in currentWaiters {
            waiter.resume()
        }
    }
}

actor AsyncRequestCounter {
    private var fulfilledCount = 0

    func shouldFulfill(maxFulfillments: Int) -> Bool {
        guard fulfilledCount < maxFulfillments else {
            return false
        }

        fulfilledCount += 1
        return true
    }
}

class MockUserDefaults: UserDefaults {
    private let lock = NSLock()
    private var _setCallCount = 0

    var setCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _setCallCount
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        if defaultName == "ScrutinyMonitor.installations" {
            lock.lock()
            _setCallCount += 1
            lock.unlock()
        }
        super.set(value, forKey: defaultName)
    }
}
