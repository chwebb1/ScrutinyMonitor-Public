import XCTest
@testable import ScrutinyMonitor

@MainActor
final class StatusBarControllerTests: XCTestCase {
    var sut: StatusBarController!
    var store: MonitorStore!
    var userDefaults: UserDefaults!
    let suiteName = "com.scrutinymonitor.tests.statusbarcontroller"

    override func setUp() async throws {
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)

        sut = StatusBarController()
        store = MonitorStore(
            client: .shared,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )
        sut.start(store: store)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        sut = nil
        store = nil
        userDefaults = nil
    }

    func testStatusSymbolName_EmptyInstallations() {
        store.installations = []
        XCTAssertEqual(sut.statusSymbolName, "externaldrive")
    }

    func testStatusSymbolName_CriticalStatus() {
        var installation = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        installation.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 0, warningDrives: 0, criticalDrives: 1, devices: [], collectedAt: Date())
        store.installations = [installation]
        XCTAssertEqual(sut.statusSymbolName, "externaldrive.badge.xmark")
    }

    func testStatusSymbolName_WarningStatus() {
        var installation = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        installation.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 0, warningDrives: 1, criticalDrives: 0, devices: [], collectedAt: Date())
        store.installations = [installation]
        XCTAssertEqual(sut.statusSymbolName, "externaldrive.badge.exclamationmark")
    }

    func testStatusSymbolName_OfflineStatus() {
        var installation = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        installation.lastError = "Offline Error"
        store.installations = [installation]
        XCTAssertEqual(sut.statusSymbolName, "wifi.slash")
    }

    func testStatusSymbolName_RefreshingStatus() {
        var installation = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        installation.isRefreshing = true
        store.installations = [installation]
        XCTAssertEqual(sut.statusSymbolName, "arrow.clockwise")
    }

    func testStatusSymbolName_DefaultStatus() {
        var installation = ScrutinyInstallation(id: UUID(), name: "Test", baseURL: URL(string: "http://localhost")!)
        installation.lastSnapshot = InstallationSnapshot(healthOK: true, totalDrives: 1, healthyDrives: 1, warningDrives: 0, criticalDrives: 0, devices: [], collectedAt: Date())
        store.installations = [installation]
        XCTAssertEqual(sut.statusSymbolName, "externaldrive")
    }

    func testSetVisible() {
        // Clear statusItem from previous setup/updates
        sut.statusItem = nil

        // When setting to false, it should remain nil/be nil
        sut.setVisible(false)
        XCTAssertNil(sut.statusItem)

        // When setting to true, it should create statusItem
        sut.setVisible(true)
        XCTAssertNotNil(sut.statusItem)
    }

    func testOpenSettings() {
        let mockWorkspace = MockAppWorkspace()
        sut.workspace = mockWorkspace

        let mainMenu = NSMenu(title: "Main Menu")
        let appMenu = NSMenu(title: "App")
        let appMenuItem = NSMenuItem(title: "App", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let settingsMenuItem = NSMenuItem(title: "Settings...", action: NSSelectorFromString("showSettingsWindow:"), keyEquivalent: ",")
        let settingsTarget = NSObject()
        settingsMenuItem.target = settingsTarget
        appMenu.addItem(settingsMenuItem)

        mockWorkspace.mainMenu = mainMenu

        sut.openSettings()

        XCTAssertTrue(mockWorkspace.activated)
        XCTAssertTrue(mockWorkspace.flag)
        XCTAssertEqual(mockWorkspace.sentActions.count, 1)
        XCTAssertEqual(mockWorkspace.sentActions.first?.0, NSSelectorFromString("showSettingsWindow:"))
        XCTAssertTrue(mockWorkspace.sentActions.first?.1 as AnyObject === settingsTarget)
        XCTAssertTrue(mockWorkspace.sentActions.first?.2 as AnyObject === settingsMenuItem)
    }
}

private final class MockAppWorkspace: AppWorkspace {
    var activated = false
    var flag = false
    var windows: [NSWindow] = []
    var mainMenu: NSMenu? = nil
    var sentActions: [(Selector, Any?, Any?)] = []

    func activate(ignoringOtherApps flag: Bool) {
        self.activated = true
        self.flag = flag
    }

    @discardableResult
    func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool {
        sentActions.append((action, target, sender))
        return true
    }
}
