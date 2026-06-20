import XCTest
@testable import ScrutinyMonitor

final class FolderSettingsSyncBackendTests: XCTestCase {
    var userDefaults: UserDefaults!
    var sut: FolderSettingsSyncBackend!
    let suiteName = "com.scrutinymonitor.tests.folderbackend"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        sut = FolderSettingsSyncBackend(provider: .selectFolder, defaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        sut = nil
        super.tearDown()
    }

    func testProviderType() {
        XCTAssertEqual(sut.provider, .selectFolder)
    }

    func testStatusWhenNotConfigured() {
        let status = sut.status
        XCTAssertEqual(status.provider, .selectFolder)
        XCTAssertFalse(status.isConfigured)
        XCTAssertFalse(status.isAvailable)
        XCTAssertEqual(status.message, "Choose a sync folder")
    }

    func testStatusWhenConfigured() {
        userDefaults.set("/tmp/scrutiny-test-sync", forKey: SettingsSyncDefaults.folderPathKey(for: .selectFolder))
        let status = sut.status
        XCTAssertEqual(status.provider, .selectFolder)
        XCTAssertTrue(status.isConfigured)
        XCTAssertTrue(status.isAvailable)
        XCTAssertEqual(status.message, "/tmp/scrutiny-test-sync")
    }

    func testLoadPayloadThrowsWhenNotConfigured() async {
        do {
            _ = try await sut.loadPayload()
            XCTFail("Expected loadPayload to throw when provider is not configured")
        } catch SettingsSyncError.providerNotConfigured(let provider) {
            XCTAssertEqual(provider, .selectFolder)
        } catch {
            XCTFail("Expected providerNotConfigured error, got: \(error)")
        }
    }

    private func createTemporaryFolder() throws -> URL {
        let folderURL = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .appendingPathComponent("ScrutinyFolderSyncBackendTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }

    func testLoadPayloadSuccess() async throws {
        let folderURL = try createTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        try saveFolderURL(folderURL, provider: .selectFolder, defaults: userDefaults)

        let payload = SettingsSyncPayload(
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

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: fileURL)

        let loadedPayload = try await sut.loadPayload()

        XCTAssertEqual(loadedPayload, payload)
    }

    func testLoadPayloadReturnsNilOnEmptyFile() async throws {
        let folderURL = try createTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        try saveFolderURL(folderURL, provider: .selectFolder, defaults: userDefaults)

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        try Data().write(to: fileURL, options: .atomic)

        let loadedPayload = try await sut.loadPayload()

        XCTAssertNil(loadedPayload, "Expected loadPayload to return nil when file is empty")
    }

    func testSavePayloadThrowsWhenNotConfigured() async {
        let payload = SettingsSyncPayload()
        do {
            try await sut.savePayload(payload)
            XCTFail("Expected savePayload to throw when provider is not configured")
        } catch SettingsSyncError.providerNotConfigured(let provider) {
            XCTAssertEqual(provider, .selectFolder)
        } catch {
            XCTFail("Expected providerNotConfigured error, got: \(error)")
        }
    }

    func testSavePayloadSuccess() async throws {
        let folderURL = try createTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        try saveFolderURL(folderURL, provider: .selectFolder, defaults: userDefaults)

        let payload = SettingsSyncPayload(
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

        try await sut.savePayload(payload)

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        let data = try Data(contentsOf: fileURL)
        let loaded = try JSONDecoder().decode(SettingsSyncPayload.self, from: data)
        XCTAssertEqual(loaded, payload)
    }

    func testStartObservingDoesNotTriggerCallbackWhenNotConfigured() {
        sut.startObserving {
            XCTFail("Should not trigger change block")
        }
        XCTAssertNil(sut.presentedItemURL)
    }

    func testLoadPayloadThrowsDecodingError() async throws {
        let folderURL = try createTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        try saveFolderURL(folderURL, provider: .selectFolder, defaults: userDefaults)

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)

        let jsonString = """
        {
            "version": "not-an-int"
        }
        """
        let invalidJSON = try XCTUnwrap(jsonString.data(using: .utf8))
        try invalidJSON.write(to: fileURL)

        do {
            _ = try await sut.loadPayload()
            XCTFail("Expected loadPayload to throw DecodingError")
        } catch let error as DecodingError {
            switch error {
            case .typeMismatch:
                break
            default:
                XCTFail("Expected typeMismatch DecodingError, got: \(error)")
            }
        } catch {
            XCTFail("Expected DecodingError, got: \(error)")
        }
    }

    func testLoadPayloadThrowsReadError() async throws {
        let folderURL = try createTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        try saveFolderURL(folderURL, provider: .selectFolder, defaults: userDefaults)

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)

        do {
            _ = try await sut.loadPayload()
            XCTFail("Expected loadPayload to throw a file read error")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertTrue(
                [
                    NSFileReadUnknownError,
                    NSFileReadNoPermissionError,
                    NSFileReadNoSuchFileError
                ].contains(nsError.code)
            )
        }
    }

    func testSavePayloadThrowsWriteError() async throws {
        let folderURL = try createTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        try saveFolderURL(folderURL, provider: .selectFolder, defaults: userDefaults)

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)

        let payload = SettingsSyncPayload()

        do {
            try await sut.savePayload(payload)
            XCTFail("Expected savePayload to throw a file write error")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertTrue(
                [
                    NSFileWriteUnknownError,
                    NSFileWriteNoPermissionError,
                    NSFileWriteFileExistsError
                ].contains(nsError.code)
            )
        }
    }

    @MainActor
    func testPresentedItemDidChangePropagation() async throws {
        let folderURL = try createTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        try saveFolderURL(folderURL, provider: .selectFolder, defaults: userDefaults)

        class ExpectationHolder {
            var expectation: XCTestExpectation?
            func fulfill() { expectation?.fulfill() }
        }
        let holder = ExpectationHolder()

        let expectation1 = XCTestExpectation(description: "external change callback called via presenter")
        holder.expectation = expectation1
        
        sut.startObserving {
            holder.fulfill()
        }

        // Verify presentedItemURL is set correctly using standardized path to avoid symlink equality issues
        let presentedPath = sut.presentedItemURL?.path.replacingOccurrences(of: "/private/var/", with: "/var/")
        let expectedPath = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName).path.replacingOccurrences(of: "/private/var/", with: "/var/")
        XCTAssertEqual(presentedPath, expectedPath)

        // Directly call the NSFilePresenter callback to verify it propagates to our closure
        sut.presentedItemDidChange()

        await fulfillment(of: [expectation1], timeout: 1.0)

        sut.stopObserving()

        // Verify presentedItemURL is cleared after stopObserving
        XCTAssertNil(sut.presentedItemURL)

        let expectation2 = XCTestExpectation(description: "external change callback not called after stop via presenter")
        expectation2.isInverted = true
        holder.expectation = expectation2

        sut.presentedItemDidChange()

        await fulfillment(of: [expectation2], timeout: 0.5)
    }

    @MainActor
    func testStartObservingOnExternalChange() async throws {
        let folderURL = try createTemporaryFolder()
        defer {
            do {
                try FileManager.default.removeItem(at: folderURL)
            } catch {
                XCTFail("Failed to clean up temporary test directory: \(error)")
            }
        }

        try saveFolderURL(folderURL, provider: .selectFolder, defaults: userDefaults)

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        let initialPayload = SettingsSyncPayload()
        try JSONEncoder().encode(initialPayload).write(to: fileURL, options: .atomic)

        let updatedPayload = SettingsSyncPayload(
            preferences: AppPreferencesSyncState(
                values: AppPreferenceValues(
                    autoRefreshEnabled: true,
                    autoRefreshInterval: 120,
                    driveFailureNotificationsEnabled: false,
                    desktopNotificationsEnabled: true
                ),
                updatedAt: Date(timeIntervalSince1970: 300)
            )
        )
        var callbackPayload: SettingsSyncPayload?
        var callbackReadError: Error?

        let externalChangeExpectation = XCTestExpectation(description: "external change callback observed updated payload")
        sut.startObserving {
            Task {
                do {
                    if let loaded = try await self.sut.loadPayload(), loaded == updatedPayload {
                        if callbackPayload == nil {
                            callbackPayload = loaded
                            externalChangeExpectation.fulfill()
                        }
                    }
                } catch {
                        callbackReadError = error
                        XCTFail("Failed to load payload after change notification: \(error)")
                        externalChangeExpectation.fulfill()
                }
            }
        }
        defer {
            sut.stopObserving()
        }

        let presentedPath = sut.presentedItemURL?.resolvingSymlinksInPath().path
        let expectedPath = fileURL.resolvingSymlinksInPath().path
        XCTAssertEqual(presentedPath, expectedPath)

        // Yield/sleep briefly to ensure the NSFilePresenter registration propagates
        // to the file system before we simulate an external change.
        try await Task.sleep(nanoseconds: 100_000_000)

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var writeError: Error?

        coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { url in
            do {
                let data = try JSONEncoder().encode(updatedPayload)
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let writeError {
            throw writeError
        }

        let presenterCallbackTimeout = 5.0
        await fulfillment(of: [externalChangeExpectation], timeout: presenterCallbackTimeout)
        XCTAssertNil(callbackReadError)
        XCTAssertNotNil(callbackPayload)
        XCTAssertEqual(callbackPayload, updatedPayload)

        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode(SettingsSyncPayload.self, from: data)
            XCTAssertEqual(loaded, updatedPayload)
        } catch {
            XCTFail("Failed to verify test data: \(error)")
        }
    }
}
