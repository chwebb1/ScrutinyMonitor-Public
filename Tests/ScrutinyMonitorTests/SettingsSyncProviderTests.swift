import XCTest
@testable import ScrutinyMonitor

final class SettingsSyncProviderTests: XCTestCase {

    func testID() {
        XCTAssertEqual(SettingsSyncProvider.iCloud.id, "iCloud")
        XCTAssertEqual(SettingsSyncProvider.selectFolder.id, "selectFolder")
        XCTAssertEqual(SettingsSyncProvider.webDAV.id, "webDAV")
    }

    func testDisplayName() {
        XCTAssertEqual(SettingsSyncProvider.iCloud.displayName, "iCloud")
        XCTAssertEqual(SettingsSyncProvider.selectFolder.displayName, "Select a folder")
        XCTAssertEqual(SettingsSyncProvider.webDAV.displayName, "WebDAV")
    }

    func testSymbolName() {
        XCTAssertEqual(SettingsSyncProvider.iCloud.symbolName, "icloud.fill")
        XCTAssertEqual(SettingsSyncProvider.selectFolder.symbolName, "folder.fill")
        XCTAssertEqual(SettingsSyncProvider.webDAV.symbolName, "network")
    }

    func testUsesFolder() {
        XCTAssertFalse(SettingsSyncProvider.iCloud.usesFolder)
        XCTAssertTrue(SettingsSyncProvider.selectFolder.usesFolder)
        XCTAssertFalse(SettingsSyncProvider.webDAV.usesFolder)
    }
}
