import XCTest
@testable import ScrutinyMonitor

final class MockSettingsSyncBackend: SettingsSyncBackend {
    var provider: SettingsSyncProvider = .iCloud
    var status: SettingsSyncStatus = SettingsSyncStatus(
        provider: .iCloud,
        isConfigured: true,
        isAvailable: true,
        message: "",
        lastSyncDate: nil
    )
    
    var errorToThrow: Error?
    var payloadToReturn: SettingsSyncPayload?
    var onLoadPayload: (() -> Void)?
    var onSavePayload: (() -> Void)?
    
    func startObserving(_ onExternalChange: @escaping @Sendable @MainActor () -> Void) {}
    func stopObserving() {}
    
    func loadPayload() async throws -> SettingsSyncPayload? {
        onLoadPayload?()
        if let error = errorToThrow {
            throw error
        }
        return payloadToReturn
    }
    
    func savePayload(_ payload: SettingsSyncPayload) async throws {
        onSavePayload?()
        if let error = errorToThrow {
            throw error
        }
        self.payloadToReturn = payload
    }
}

final class CloudSettingsSynchronizerTests: XCTestCase {
    override func tearDown() {
        KeychainHelper.resetTestState()
        super.tearDown()
    }

    func testFolderBackendRoundTripsPayload() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrutinyMonitorSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        defaults.set(folderURL.path, forKey: SettingsSyncDefaults.folderPathKey(for: .selectFolder))

        let id = UUID()
        let payload = SettingsSyncPayload(
            installations: InstallationSyncEnvelope(records: [
                InstallationSyncRecord(
                    id: id,
                    name: "Folder NAS",
                    baseURL: URL(string: "http://folder.local:8080")!,
                    updatedAt: Date(timeIntervalSince1970: 100)
                )
            ]),
            preferences: AppPreferencesSyncState(
                values: AppPreferenceValues(
                    autoRefreshEnabled: true,
                    autoRefreshInterval: 60,
                    driveFailureNotificationsEnabled: true,
                    desktopNotificationsEnabled: false
                ),
                updatedAt: Date(timeIntervalSince1970: 200)
            )
        )

        let backend = FolderSettingsSyncBackend(provider: .selectFolder, defaults: defaults)

        try await backend.savePayload(payload)
        let loadedPayload = try await backend.loadPayload()

        XCTAssertEqual(loadedPayload, payload)
    }

    func testMergeAddsRemoteInstallationWithLocalToken() {
        let id = UUID()
        let remoteUpdatedAt = Date(timeIntervalSince1970: 100)
        let envelope = InstallationSyncEnvelope(records: [
            InstallationSyncRecord(
                id: id,
                name: "Office NAS",
                baseURL: URL(string: "http://office.local:8080")!,
                updatedAt: remoteUpdatedAt
            )
        ])

        let result = InstallationSyncEngine.merge(
            localInstallations: [],
            envelope: envelope,
            metadata: InstallationSyncMetadata(),
            now: Date(timeIntervalSince1970: 200),
            tokenProvider: { tokenID in tokenID == id ? "local-token".data(using: .utf8)! : nil }
        )

        XCTAssertEqual(result.installations.count, 1)
        XCTAssertEqual(result.installations.first?.id, id)
        XCTAssertEqual(result.installations.first?.apiToken, "local-token".data(using: .utf8)!)
        XCTAssertEqual(result.metadata.recordUpdates[id], remoteUpdatedAt)
        XCTAssertTrue(result.changedInstallations)
        XCTAssertFalse(result.needsCloudPublish)
    }

    func testRemoteDeletionRemovesOlderLocalInstallation() {
        let id = UUID()
        let localUpdatedAt = Date(timeIntervalSince1970: 50)
        let remoteDeletedAt = Date(timeIntervalSince1970: 100)
        let localInstallation = ScrutinyInstallation(
            id: id,
            name: "Garage NAS",
            baseURL: URL(string: "http://garage.local:8080")!,
            apiToken: "local-token".data(using: .utf8)!
        )

        let result = InstallationSyncEngine.merge(
            localInstallations: [localInstallation],
            envelope: InstallationSyncEnvelope(deletions: [
                InstallationSyncDeletion(id: id, deletedAt: remoteDeletedAt)
            ]),
            metadata: InstallationSyncMetadata(recordUpdates: [id: localUpdatedAt]),
            now: Date(timeIntervalSince1970: 200),
            tokenProvider: { _ in nil }
        )

        XCTAssertTrue(result.installations.isEmpty)
        XCTAssertEqual(result.deletedTokenIDs, [id])
        XCTAssertEqual(result.metadata.deletions[id], remoteDeletedAt)
        XCTAssertTrue(result.changedInstallations)
    }

    func testNewerRemoteRecordWinsOverOlderDeletion() {
        let id = UUID()
        let remoteDeletedAt = Date(timeIntervalSince1970: 100)
        let remoteUpdatedAt = Date(timeIntervalSince1970: 200)

        let result = InstallationSyncEngine.merge(
            localInstallations: [],
            envelope: InstallationSyncEnvelope(
                records: [
                    InstallationSyncRecord(
                        id: id,
                        name: "Recovered NAS",
                        baseURL: URL(string: "http://recovered.local:8080")!,
                        updatedAt: remoteUpdatedAt
                    )
                ],
                deletions: [
                    InstallationSyncDeletion(id: id, deletedAt: remoteDeletedAt)
                ]
            ),
            metadata: InstallationSyncMetadata(),
            now: Date(timeIntervalSince1970: 300),
            tokenProvider: { _ in nil }
        )

        XCTAssertEqual(result.installations.map(\.id), [id])
        XCTAssertTrue(result.deletedTokenIDs.isEmpty)
        XCTAssertEqual(result.metadata.recordUpdates[id], remoteUpdatedAt)
        XCTAssertTrue(result.needsCloudPublish)
    }

    func testLocalNewerRecordWinsAndRequestsPublish() {
        let id = UUID()
        let localUpdatedAt = Date(timeIntervalSince1970: 200)
        let remoteUpdatedAt = Date(timeIntervalSince1970: 100)
        let localInstallation = ScrutinyInstallation(
            id: id,
            name: "New Name",
            baseURL: URL(string: "http://new.local:8080")!,
            apiToken: Data()
        )

        let result = InstallationSyncEngine.merge(
            localInstallations: [localInstallation],
            envelope: InstallationSyncEnvelope(records: [
                InstallationSyncRecord(
                    id: id,
                    name: "Old Name",
                    baseURL: URL(string: "http://old.local:8080")!,
                    updatedAt: remoteUpdatedAt
                )
            ]),
            metadata: InstallationSyncMetadata(recordUpdates: [id: localUpdatedAt]),
            now: Date(timeIntervalSince1970: 300),
            tokenProvider: { _ in nil }
        )

        XCTAssertEqual(result.installations.first?.name, "New Name")
        XCTAssertEqual(result.installations.first?.baseURL.absoluteString, "http://new.local:8080")
        XCTAssertFalse(result.changedInstallations)
        XCTAssertTrue(result.needsCloudPublish)
    }

    func testPublishingEnvelopeOmitsAPIToken() throws {
        let id = UUID()
        let updatedAt = Date(timeIntervalSince1970: 100)
        let installation = ScrutinyInstallation(
            id: id,
            name: "Secret NAS",
            baseURL: URL(string: "http://secret.local:8080")!,
            apiToken: "super-secret-token".data(using: .utf8)!
        )

        let envelope = InstallationSyncEngine.publishingEnvelope(
            installations: [installation],
            metadata: InstallationSyncMetadata(recordUpdates: [id: updatedAt]),
            existingEnvelope: nil,
            now: Date(timeIntervalSince1970: 200)
        )

        let data = try JSONEncoder().encode(envelope)
        let payload = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(envelope.records.first?.id, id)
        XCTAssertFalse(payload.contains("super-secret-token"))
    }

    @MainActor
    func testPreferenceSyncInitialPublish() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.Prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrutinyMonitorSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        defaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)
        defaults.set(folderURL.path, forKey: SettingsSyncDefaults.folderPathKey(for: .selectFolder))

        // Set local preference values
        defaults.set(true, forKey: AppPreferences.autoRefreshEnabledKey)
        defaults.set(60.0, forKey: AppPreferences.autoRefreshIntervalKey)

        let mockStore = NSUbiquitousKeyValueStore() // Dummy key value store since we use folder sync
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)
        
        await synchronizer.syncNow()

        // Verify local preferences were published
        let backend = FolderSettingsSyncBackend(provider: .selectFolder, defaults: defaults)
        let publishedPayload = try await backend.loadPayload()

        XCTAssertNotNil(publishedPayload)
        XCTAssertEqual(publishedPayload?.preferences?.values.autoRefreshEnabled, true)
        XCTAssertEqual(publishedPayload?.preferences?.values.autoRefreshInterval, 60.0)
    }

    @MainActor
    func testPreferenceSyncRemoteStateWins() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.Prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrutinyMonitorSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        defaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)
        defaults.set(folderURL.path, forKey: SettingsSyncDefaults.folderPathKey(for: .selectFolder))

        // Setup remote payload with a newer timestamp than default or local
        let remotePayload = SettingsSyncPayload(
            preferences: AppPreferencesSyncState(
                values: AppPreferenceValues(
                    autoRefreshEnabled: true,
                    autoRefreshInterval: 900.0,
                    driveFailureNotificationsEnabled: true,
                    desktopNotificationsEnabled: true
                ),
                updatedAt: Date(timeIntervalSince1970: 500)
            )
        )

        let backend = FolderSettingsSyncBackend(provider: .selectFolder, defaults: defaults)
        try await backend.savePayload(remotePayload)

        // Set local preference values with an older updatedAt timestamp in defaults metadata
        defaults.set(Date(timeIntervalSince1970: 100), forKey: "ScrutinyMonitor.cloud.preferencesUpdatedAt.v1")
        defaults.set(false, forKey: AppPreferences.autoRefreshEnabledKey)
        defaults.set(300.0, forKey: AppPreferences.autoRefreshIntervalKey)

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        await synchronizer.syncNow()

        // Assert local defaults are updated to match remote state
        XCTAssertTrue(defaults.bool(forKey: AppPreferences.autoRefreshEnabledKey))
        XCTAssertEqual(defaults.double(forKey: AppPreferences.autoRefreshIntervalKey), 900.0)
        XCTAssertTrue(defaults.bool(forKey: AppPreferences.driveFailureNotificationsEnabledKey))
        XCTAssertTrue(defaults.bool(forKey: AppPreferences.desktopNotificationsEnabledKey))
    }

    @MainActor
    func testPreferenceSyncLocalStateWins() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.Prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrutinyMonitorSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        defaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)
        defaults.set(folderURL.path, forKey: SettingsSyncDefaults.folderPathKey(for: .selectFolder))

        // Setup remote payload with an older timestamp
        let remotePayload = SettingsSyncPayload(
            preferences: AppPreferencesSyncState(
                values: AppPreferenceValues(
                    autoRefreshEnabled: false,
                    autoRefreshInterval: 900.0,
                    driveFailureNotificationsEnabled: false,
                    desktopNotificationsEnabled: false
                ),
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        )

        let backend = FolderSettingsSyncBackend(provider: .selectFolder, defaults: defaults)
        try await backend.savePayload(remotePayload)

        // Set local preference values with a newer updatedAt timestamp
        defaults.set(Date(timeIntervalSince1970: 500), forKey: "ScrutinyMonitor.cloud.preferencesUpdatedAt.v1")
        defaults.set(true, forKey: AppPreferences.autoRefreshEnabledKey)
        defaults.set(60.0, forKey: AppPreferences.autoRefreshIntervalKey)

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        await synchronizer.syncNow()

        // Verify remote state didn't overwrite local since local has newer timestamp
        XCTAssertTrue(defaults.bool(forKey: AppPreferences.autoRefreshEnabledKey))
        XCTAssertEqual(defaults.double(forKey: AppPreferences.autoRefreshIntervalKey), 60.0)

        // Verify the cloud was updated to local preferences
        let loaded = try await backend.loadPayload()
        XCTAssertEqual(loaded?.preferences?.values.autoRefreshEnabled, true)
        XCTAssertEqual(loaded?.preferences?.values.autoRefreshInterval, 60.0)
    }

    @MainActor
    func testDefaultsChangeTriggersSync() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.Prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        // Set initial values
        defaults.set(false, forKey: AppPreferences.autoRefreshEnabledKey)
        defaults.set(300.0, forKey: AppPreferences.autoRefreshIntervalKey)

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)
        let mockBackend = MockSettingsSyncBackend()

        // Explicitly match mock provider to prevent backend overwrite
        defaults.set(SettingsSyncProvider.iCloud.rawValue, forKey: SettingsSyncDefaults.providerKey)

        // Inject mock backend
        synchronizer.backend = mockBackend
        synchronizer.activeProvider = .iCloud

        _ = synchronizer.start()

        let saveExpectation = expectation(description: "Wait for payload to be saved")
        saveExpectation.expectedFulfillmentCount = 2 // Once for reconcilePreferences in start(), once for handleDefaultsChange
        saveExpectation.assertForOverFulfill = false
        mockBackend.onSavePayload = {
            saveExpectation.fulfill()
        }

        // Modify a preference locally (simulating user action in UI)
        defaults.set(true, forKey: AppPreferences.autoRefreshEnabledKey)
        defaults.set(60.0, forKey: AppPreferences.autoRefreshIntervalKey)

        // Post didChangeNotification to trigger handleDefaultsChange
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)

        await fulfillment(of: [saveExpectation], timeout: 1.0)

        // Verify payload was updated
        XCTAssertEqual(mockBackend.payloadToReturn?.preferences?.values.autoRefreshEnabled, true)
        XCTAssertEqual(mockBackend.payloadToReturn?.preferences?.values.autoRefreshInterval, 60.0)
    }

    @MainActor
    func testLoadPayloadErrorHandling() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.Error.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrutinyMonitorSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        defaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)
        defaults.set(folderURL.path, forKey: SettingsSyncDefaults.folderPathKey(for: .selectFolder))

        // Write invalid data to the sync file to trigger a load error
        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        let invalidData = "invalid-json".data(using: .utf8)!
        try invalidData.write(to: fileURL)

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        // syncNow will attempt to reconcile preferences and thus load the payload
        await synchronizer.syncNow()

        // Capture the expected error's secure description
        var expectedErrorMessage = ""
        do {
            _ = try JSONDecoder().decode(SettingsSyncPayload.self, from: invalidData)
        } catch {
            expectedErrorMessage = error.secureDescription
        }

        XCTAssertFalse(expectedErrorMessage.isEmpty, "Failed to capture expected error message")
        XCTAssertEqual(synchronizer.currentStatus.message, expectedErrorMessage)
    }

    @MainActor
    func testLoadPayloadDecodingErrorHandling() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.Error.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrutinyMonitorSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        defaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)
        defaults.set(folderURL.path, forKey: SettingsSyncDefaults.folderPathKey(for: .selectFolder))

        // Write invalid data to the sync file to trigger a load error
        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        let invalidData = "invalid-json".data(using: .utf8)!
        try invalidData.write(to: fileURL)

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        // Capture the expected error's secure description
        var expectedErrorMessage = ""
        do {
            _ = try JSONDecoder().decode(SettingsSyncPayload.self, from: invalidData)
        } catch {
            expectedErrorMessage = error.secureDescription
        }
        XCTAssertFalse(expectedErrorMessage.isEmpty, "Failed to capture expected error message")

        // Act
        let payload = await synchronizer.loadPayload()

        // Assert
        XCTAssertNil(payload, "Payload should be nil due to decoding error")
        XCTAssertEqual(synchronizer.lastErrorMessage, expectedErrorMessage)
    }

@MainActor
    func testSyncPayloadLoadErrorHandling() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.Error.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        let mockBackend = MockSettingsSyncBackend()
        mockBackend.errorToThrow = SettingsSyncError.serverRejectedRequest(500)

        synchronizer.backend = mockBackend
        synchronizer.activeProvider = synchronizer.selectedProvider

        let payload = await synchronizer.loadPayload()

        XCTAssertNil(payload)
        XCTAssertEqual(synchronizer.lastErrorMessage, "The sync server returned HTTP 500.")
    }

    @MainActor
    func testStartSetsUpObserversAndPreventsDoubleExecution() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.Start.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        XCTAssertFalse(synchronizer.isStarted)
        XCTAssertNil(synchronizer.defaultsObserver)

        let result1 = synchronizer.start()

        XCTAssertTrue(result1)
        XCTAssertTrue(synchronizer.isStarted)
        XCTAssertNotNil(synchronizer.defaultsObserver)

        let observerRef = synchronizer.defaultsObserver

        let result2 = synchronizer.start()

        XCTAssertTrue(result2)
        // Check that the observer reference hasn't been overwritten by a second call
        XCTAssertIdentical(observerRef, synchronizer.defaultsObserver)
    }

    @MainActor
    func testSetWebDAVConfigurationRejectsPasswordWithoutUsername() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.WebDAV.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        do {
            try synchronizer.setWebDAVConfiguration(urlString: "https://example.com/webdav", username: "   ", password: "secret_password")
            XCTFail("Expected setWebDAVConfiguration to throw SettingsSyncError.passwordWithoutUsername")
        } catch SettingsSyncError.passwordWithoutUsername {
            // Expected
        } catch {
            XCTFail("Expected passwordWithoutUsername, but got \(error)")
        }
    }

    @MainActor
    func testSetWebDAVConfigurationRejectsInlineCredentials() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.WebDAV.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        do {
            try synchronizer.setWebDAVConfiguration(urlString: "https://user:pass@example.com/webdav", username: "testuser", password: "testpassword")
            XCTFail("Expected setWebDAVConfiguration to throw SettingsSyncError.inlineCredentialsNotSupported")
        } catch SettingsSyncError.inlineCredentialsNotSupported {
            // Expected
        } catch {
            XCTFail("Expected inlineCredentialsNotSupported, but got \(error)")
        }

        do {
            try synchronizer.setWebDAVConfiguration(urlString: "https://user:@example.com/webdav", username: "testuser", password: "testpassword")
            XCTFail("Expected setWebDAVConfiguration to throw SettingsSyncError.inlineCredentialsNotSupported for empty password")
        } catch SettingsSyncError.inlineCredentialsNotSupported {
            // Expected
        } catch {
            XCTFail("Expected inlineCredentialsNotSupported, but got \(error)")
        }
    }

    @MainActor
    func testSetWebDAVConfigurationRejectsURLWithOnlyUsername() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.WebDAV.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        do {
            try synchronizer.setWebDAVConfiguration(urlString: "https://user@example.com/webdav", username: "testuser", password: "testpassword")
            XCTFail("Expected setWebDAVConfiguration to throw SettingsSyncError.inlineCredentialsNotSupported")
        } catch SettingsSyncError.inlineCredentialsNotSupported {
            // Expected
        } catch {
            XCTFail("Expected inlineCredentialsNotSupported, but got \(error)")
        }
    }

    @MainActor
    func testSetWebDAVConfigurationAcceptsValidURL() async throws {
        let defaultsName = "CloudSettingsSynchronizerTests.WebDAV.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let mockStore = NSUbiquitousKeyValueStore()
        let synchronizer = CloudSettingsSynchronizer(keyValueStore: mockStore, defaults: defaults)

        do {
            try synchronizer.setWebDAVConfiguration(urlString: "https://example.com/webdav", username: "testuser", password: "testpassword")
            XCTAssertEqual(defaults.string(forKey: SettingsSyncDefaults.webDAVURLKey), "https://example.com/webdav")

            let savedUsernameData = KeychainHelper.shared.readData(
                service: SettingsSyncDefaults.webDAVUsernameService,
                account: SettingsSyncDefaults.webDAVUsernameAccount
            )
            let savedPasswordData = KeychainHelper.shared.readData(
                service: SettingsSyncDefaults.webDAVPasswordService,
                account: SettingsSyncDefaults.webDAVPasswordAccount
            )
            XCTAssertEqual(savedUsernameData, Data("testuser".utf8))
            XCTAssertEqual(savedPasswordData, Data("testpassword".utf8))
        } catch {
            XCTFail("Expected valid URL to be accepted, but got \(error)")
        }
    }
}
