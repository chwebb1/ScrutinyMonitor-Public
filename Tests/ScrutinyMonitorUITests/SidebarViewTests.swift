import XCTest
import SwiftUI
import ViewInspector
@testable import ScrutinyMonitor

final class SidebarViewTests: XCTestCase {
    var userDefaults: UserDefaults!
    var store: MonitorStore!
    let suiteName = "com.scrutinymonitor.tests.sidebarview"

    @MainActor
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)

        let persistence = InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false)
        let cloudSync = CloudSettingsSynchronizer(defaults: userDefaults)
        let notificationService = DriveFailureNotificationService(defaults: userDefaults)

        store = MonitorStore(
            client: .shared,
            persistence: persistence,
            cloudSync: cloudSync,
            notificationService: notificationService
        )
    }

    @MainActor
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        store = nil
        userDefaults = nil
        super.tearDown()
    }

    @MainActor
    func testSidebarEmptyState() throws {
        XCTAssertTrue(store.installations.isEmpty)
        
        let view = SidebarView(
            store: store,
            onAddInstallation: {},
            onEditInstallation: {},
            onDeleteInstallation: {}
        )

        // Empty state should show ContentUnavailableView on macOS 14
        let unavailableView = try view.inspect().find(ViewType.ContentUnavailableView.self)
        XCTAssertNotNil(unavailableView)
        
        let label = try unavailableView.find(ViewType.Label.self)
        XCTAssertEqual(try label.find(ViewType.Text.self).string(), "No Installations")
    }

    @MainActor
    func testSidebarPopulatedState() throws {
        // Add a test installation
        let id = UUID()
        let installation = ScrutinyInstallation(
            id: id,
            name: "Server A",
            baseURL: URL(string: "https://servera.local")!,
            apiToken: Data()
        )
        store.installations = [installation]

        let view = SidebarView(
            store: store,
            onAddInstallation: {},
            onEditInstallation: {},
            onDeleteInstallation: {}
        )

        // Find the List
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list)

        // Verify there is an InstallationRow for Server A
        let row = try view.inspect().find(text: "Server A")
        XCTAssertNotNil(row)
    }

    @MainActor
    func testSidebarActionBarLayout() throws {
        let view = SidebarView(
            store: store,
            onAddInstallation: {},
            onEditInstallation: {},
            onDeleteInstallation: {}
        )

        // Find the SidebarActionBar
        let actionBar = try view.inspect().find(SidebarActionBar.self)
        XCTAssertNotNil(actionBar)

        // Assert buttons exist (Add Installation button exists)
        let addBtn = try actionBar.find(button: "Add Installation")
        XCTAssertNotNil(addBtn)
    }
}
