import XCTest
import SwiftUI
import ViewInspector
@testable import ScrutinyMonitor

final class SettingsViewTests: XCTestCase {
    var userDefaults: UserDefaults!
    var synchronizer: CloudSettingsSynchronizer!
    let suiteName = "com.scrutinymonitor.tests.settingsview"

    @MainActor
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        
        userDefaults.set(SettingsSyncProvider.iCloud.rawValue, forKey: SettingsSyncDefaults.providerKey)
        synchronizer = CloudSettingsSynchronizer(keyValueStore: NSUbiquitousKeyValueStore(), defaults: userDefaults)
    }

    @MainActor
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        synchronizer = nil
        userDefaults = nil
        super.tearDown()
    }

    @MainActor
    func testSettingsViewLayoutSections() throws {
        let view = SettingsView(defaults: userDefaults, synchronizer: synchronizer)
        
        // Assert the forms and toggles exist
        let autoRefreshToggle = try view.inspect().find(ViewType.Toggle.self, containing: "Auto-refresh SMART status")
        XCTAssertNotNil(autoRefreshToggle)

        let failureAlertsToggle = try view.inspect().find(ViewType.Toggle.self, containing: "Notify when a drive begins failing")
        XCTAssertNotNil(failureAlertsToggle)
    }

    @MainActor
    func testSyncLocationPicker() throws {
        let view = SettingsView(defaults: userDefaults, synchronizer: synchronizer)

        // Find the Sync Location Picker
        let picker = try view.inspect().find(ViewType.Picker.self)
        XCTAssertNotNil(picker)
    }

    @MainActor
    func testSaveWebDAVSettingsErrorPath() throws {
        userDefaults.set(SettingsSyncProvider.webDAV.rawValue, forKey: SettingsSyncDefaults.providerKey)
        userDefaults.set("invalid-url", forKey: SettingsSyncDefaults.webDAVURLKey)
        synchronizer = CloudSettingsSynchronizer(keyValueStore: NSUbiquitousKeyValueStore(), defaults: userDefaults)
        let view = SettingsView(defaults: userDefaults, synchronizer: synchronizer)

        let exp1 = view.inspection.inspect(after: 0.1) { view in
            let button = try view.inspect().find(viewWithId: "saveWebDAVButton").button()
            try button.tap()
        }

        let exp2 = view.inspection.inspect(after: 0.3) { view in
            let text = try view.inspect().find(text: "Enter a valid WebDAV folder URL.")
            XCTAssertNotNil(text)
        }

        ViewHosting.host(view: view)
        wait(for: [exp1, exp2], timeout: 2.0)
    }
}
