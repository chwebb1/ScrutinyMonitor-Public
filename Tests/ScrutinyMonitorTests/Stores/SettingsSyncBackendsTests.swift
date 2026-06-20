import XCTest
@testable import ScrutinyMonitor

final class SettingsSyncBackendsTests: XCTestCase {

    func testSettingsSyncPayloadDefaults() {
        let payload = SettingsSyncPayload()
        XCTAssertEqual(payload.version, 1)
        XCTAssertNil(payload.installations)
        XCTAssertNil(payload.preferences)
    }

    func testSettingsSyncPayloadEquality() {
        let payload1 = SettingsSyncPayload()
        let payload2 = SettingsSyncPayload()
        XCTAssertEqual(payload1, payload2)

        var payload3 = SettingsSyncPayload()
        payload3.version = 2
        XCTAssertNotEqual(payload1, payload3)
    }

    func testSettingsSyncStatusEquality() {
        let status1 = SettingsSyncStatus(provider: .iCloud, isConfigured: true, isAvailable: true, message: "OK", lastSyncDate: nil)
        let status2 = SettingsSyncStatus(provider: .iCloud, isConfigured: true, isAvailable: true, message: "OK", lastSyncDate: nil)
        XCTAssertEqual(status1, status2)

        let status3 = SettingsSyncStatus(provider: .webDAV, isConfigured: true, isAvailable: true, message: "OK", lastSyncDate: nil)
        XCTAssertNotEqual(status1, status3)
    }

    func testSettingsSyncDefaultsKeys() {
        XCTAssertEqual(SettingsSyncDefaults.providerKey, "ScrutinyMonitor.sync.provider")
        XCTAssertEqual(SettingsSyncDefaults.lastSyncDateKey, "ScrutinyMonitor.sync.lastSyncDate")
        XCTAssertEqual(SettingsSyncDefaults.webDAVURLKey, "ScrutinyMonitor.sync.webdav.url")
        XCTAssertEqual(SettingsSyncDefaults.webDAVUsernameService, "ScrutinyMonitor.sync.webdav")
        XCTAssertEqual(SettingsSyncDefaults.webDAVUsernameAccount, "username")
        XCTAssertEqual(SettingsSyncDefaults.webDAVPasswordService, "ScrutinyMonitor.sync.webdav")
        XCTAssertEqual(SettingsSyncDefaults.webDAVPasswordAccount, "password")
        XCTAssertEqual(SettingsSyncDefaults.syncFileName, "ScrutinyMonitor.settings.json")
    }

    func testSettingsSyncDefaultsFolderBookmarkKey() {
        // Assert exact strings for known providers to prevent format regression
        XCTAssertEqual(SettingsSyncDefaults.folderBookmarkKey(for: .iCloud), "ScrutinyMonitor.sync.iCloud.folderBookmark")
        XCTAssertEqual(SettingsSyncDefaults.folderBookmarkKey(for: .selectFolder), "ScrutinyMonitor.sync.selectFolder.folderBookmark")
        XCTAssertEqual(SettingsSyncDefaults.folderBookmarkKey(for: .webDAV), "ScrutinyMonitor.sync.webDAV.folderBookmark")

        // Dynamically assert uniqueness for all current and future providers
        let allKeys = SettingsSyncProvider.allCases.map { SettingsSyncDefaults.folderBookmarkKey(for: $0) }
        XCTAssertEqual(Set(allKeys).count, SettingsSyncProvider.allCases.count, "All folder bookmark keys should be unique")
    }

    func testSettingsSyncDefaultsFolderPathKey() {
        // Assert exact strings for known providers to prevent format regression
        XCTAssertEqual(SettingsSyncDefaults.folderPathKey(for: .iCloud), "ScrutinyMonitor.sync.iCloud.folderPath")
        XCTAssertEqual(SettingsSyncDefaults.folderPathKey(for: .selectFolder), "ScrutinyMonitor.sync.selectFolder.folderPath")
        XCTAssertEqual(SettingsSyncDefaults.folderPathKey(for: .webDAV), "ScrutinyMonitor.sync.webDAV.folderPath")

        // Dynamically assert uniqueness for all current and future providers
        let allKeys = SettingsSyncProvider.allCases.map { SettingsSyncDefaults.folderPathKey(for: $0) }
        XCTAssertEqual(Set(allKeys).count, SettingsSyncProvider.allCases.count, "All folder path keys should be unique")
    }
}
