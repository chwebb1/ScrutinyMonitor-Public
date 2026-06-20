import XCTest
@testable import ScrutinyMonitor

final class MockUbiquitousKeyValueStore: NSUbiquitousKeyValueStore {
    private var storage = [String: Any]()
    private(set) var synchronizeCallCount = 0

    override func data(forKey aKey: String) -> Data? {
        storage[aKey] as? Data
    }

    override func set(_ aData: Data?, forKey aKey: String) {
        storage[aKey] = aData
    }

    override func removeObject(forKey aKey: String) {
        storage.removeValue(forKey: aKey)
    }

    override func synchronize() -> Bool {
        synchronizeCallCount += 1
        return true
    }
}

final class ICloudSettingsSyncBackendTests: XCTestCase {
    var userDefaults: UserDefaults!
    var mockKeyValueStore: MockUbiquitousKeyValueStore!
    var sut: ICloudSettingsSyncBackend!
    let suiteName = "com.scrutinymonitor.tests.icloudbackend"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        mockKeyValueStore = MockUbiquitousKeyValueStore()
        sut = ICloudSettingsSyncBackend(keyValueStore: mockKeyValueStore, defaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        mockKeyValueStore = nil
        sut = nil
        super.tearDown()
    }

    func testProviderType() {
        XCTAssertEqual(sut.provider, .iCloud)
    }

    func testStatusConfiguration() {
        let status = sut.status
        XCTAssertEqual(status.provider, .iCloud)
        XCTAssertTrue(status.isConfigured, "iCloud is always considered configured by design")
        let expectedAvailability = FileManager.default.ubiquityIdentityToken != nil
        XCTAssertEqual(status.isAvailable, expectedAvailability)
    }

    func testLoadPayloadWithInvalidDataThrowsDecodingError() async throws {
        let invalidData = try XCTUnwrap("invalid json".data(using: .utf8))
        mockKeyValueStore.set(invalidData, forKey: "ScrutinyMonitor.cloud.installations.v1")
        mockKeyValueStore.set(invalidData, forKey: "ScrutinyMonitor.cloud.preferences.v1")

        do {
            _ = try await sut.loadPayload()
            XCTFail("Expected loadPayload to throw DecodingError")
        } catch {
            XCTAssertTrue(error is DecodingError, "Expected error to be DecodingError, got \(error)")
        }
    }

    func testLoadPayloadWithOneValidOneInvalidKeyThrowsDecodingError() async throws {
        let installations = InstallationSyncEnvelope(records: [
            InstallationSyncRecord(
                id: UUID(),
                name: "iCloud NAS",
                baseURL: URL(string: "http://icloudnas.local")!,
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        ])
        let validInstallationsData = try JSONEncoder().encode(installations)
        let invalidPreferencesData = try XCTUnwrap("invalid json".data(using: .utf8))

        mockKeyValueStore.set(validInstallationsData, forKey: "ScrutinyMonitor.cloud.installations.v1")
        mockKeyValueStore.set(invalidPreferencesData, forKey: "ScrutinyMonitor.cloud.preferences.v1")

        do {
            _ = try await sut.loadPayload()
            XCTFail("Expected loadPayload to throw DecodingError when one key is corrupted")
        } catch {
            XCTAssertTrue(error is DecodingError, "Expected error to be DecodingError, got \(error)")
        }
    }

    func testLoadPayloadEmpty() async throws {
        let payload = try await sut.loadPayload()
        XCTAssertNil(payload, "Loading from empty key value store should return nil payload")
        XCTAssertEqual(mockKeyValueStore.synchronizeCallCount, 1)
    }

    func testLoadPayloadSuccess() async throws {
        let installations = InstallationSyncEnvelope(records: [
            InstallationSyncRecord(
                id: UUID(),
                name: "iCloud NAS",
                baseURL: URL(string: "http://icloudnas.local")!,
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        ])
        let preferences = AppPreferencesSyncState(
            values: AppPreferenceValues(
                autoRefreshEnabled: true,
                autoRefreshInterval: 60.0,
                driveFailureNotificationsEnabled: true,
                desktopNotificationsEnabled: true
            ),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let payload = SettingsSyncPayload(installations: installations, preferences: preferences)

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(payload.installations) {
            mockKeyValueStore.set(data, forKey: "ScrutinyMonitor.cloud.installations.v1")
        }
        if let data = try? encoder.encode(payload.preferences) {
            mockKeyValueStore.set(data, forKey: "ScrutinyMonitor.cloud.preferences.v1")
        }

        let loaded = try await sut.loadPayload()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.installations?.records.first?.name, "iCloud NAS")
        XCTAssertEqual(loaded?.preferences?.values.autoRefreshInterval, 60.0)
    }

    func testSavePayloadSuccess() async throws {
        let installations = InstallationSyncEnvelope(records: [
            InstallationSyncRecord(
                id: UUID(),
                name: "iCloud NAS",
                baseURL: URL(string: "http://icloudnas.local")!,
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        ])
        let preferences = AppPreferencesSyncState(
            values: AppPreferenceValues(
                autoRefreshEnabled: true,
                autoRefreshInterval: 60.0,
                driveFailureNotificationsEnabled: true,
                desktopNotificationsEnabled: true
            ),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let payload = SettingsSyncPayload(installations: installations, preferences: preferences)

        try await sut.savePayload(payload)
        XCTAssertEqual(mockKeyValueStore.synchronizeCallCount, 1)

        let decoder = JSONDecoder()
        if let data = mockKeyValueStore.data(forKey: "ScrutinyMonitor.cloud.installations.v1") {
            let decodedInstallations = try decoder.decode(InstallationSyncEnvelope.self, from: data)
            XCTAssertEqual(decodedInstallations.records.first?.name, "iCloud NAS")
        } else {
            XCTFail("Missing installations data in key value store")
        }

        if let data = mockKeyValueStore.data(forKey: "ScrutinyMonitor.cloud.preferences.v1") {
            let decodedPreferences = try decoder.decode(AppPreferencesSyncState.self, from: data)
            XCTAssertEqual(decodedPreferences.values.autoRefreshInterval, 60.0)
        } else {
            XCTFail("Missing preferences data in key value store")
        }
    }

    @MainActor
    func testStartAndStopObserving() async {
        class ExpectationHolder {
            var expectation: XCTestExpectation?
            func fulfill() { expectation?.fulfill() }
        }
        let holder = ExpectationHolder()

        let expectation1 = XCTestExpectation(description: "external change callback called")
        holder.expectation = expectation1
        
        sut.startObserving {
            holder.fulfill()
        }

        // Simulate Notification posted by system when ubiquitous store changes
        let userInfo: [AnyHashable: Any] = [
            NSUbiquitousKeyValueStoreChangedKeysKey: ["ScrutinyMonitor.cloud.installations.v1"]
        ]
        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: mockKeyValueStore,
            userInfo: userInfo
        )

        // Wait for main thread notification dispatch
        await fulfillment(of: [expectation1], timeout: 1.0)
        
        sut.stopObserving()

        let expectation2 = XCTestExpectation(description: "external change callback not called after stop")
        expectation2.isInverted = true
        holder.expectation = expectation2

        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: mockKeyValueStore,
            userInfo: userInfo
        )

        await fulfillment(of: [expectation2], timeout: 0.5)
    }
}
