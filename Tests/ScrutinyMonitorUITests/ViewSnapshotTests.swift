import XCTest
import SwiftUI
@testable import ScrutinyMonitor

final class ViewSnapshotTests: XCTestCase {
    var userDefaults: UserDefaults!
    var store: MonitorStore!
    let suiteName = "com.scrutinymonitor.tests.viewsnapshots"

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
    func testSettingsViewSnapshot() {
        let fixedDate = Date(timeIntervalSince1970: 1774828800) // Fixed constant date

        userDefaults.set(true, forKey: AppPreferences.autoRefreshEnabledKey)
        userDefaults.set(300.0, forKey: AppPreferences.autoRefreshIntervalKey)
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.showMenuBarExtraKey)
        userDefaults.set(SettingsSyncProvider.webDAV.rawValue, forKey: SettingsSyncDefaults.providerKey)
        userDefaults.set("https://example.com/dav/settings", forKey: SettingsSyncDefaults.webDAVURLKey)
        userDefaults.set(fixedDate, forKey: SettingsSyncDefaults.lastSyncDateKey)

        let synchronizer = CloudSettingsSynchronizer(keyValueStore: NSUbiquitousKeyValueStore(), defaults: userDefaults)
        let view = SettingsView(defaults: userDefaults, synchronizer: synchronizer)
        
        // Assert layout renders correctly in both Dark and Light modes with proper dimensions (620x700)
        assertSnapshot(matching: view, named: "SettingsView_DarkMode", width: 620, height: 700, colorScheme: .dark)
        assertSnapshot(matching: view, named: "SettingsView_LightMode", width: 620, height: 700, colorScheme: .light)
    }

    @MainActor
    func testSidebarEmptyStateSnapshot() {
        XCTAssertTrue(store.installations.isEmpty)
        let view = SidebarView(
            store: store,
            onAddInstallation: {},
            onEditInstallation: {},
            onDeleteInstallation: {}
        )
        
        assertSnapshot(matching: view, named: "SidebarView_EmptyState_DarkMode", width: 250, height: 400, colorScheme: .dark)
        assertSnapshot(matching: view, named: "SidebarView_EmptyState_LightMode", width: 250, height: 400, colorScheme: .light)
    }

    @MainActor
    func testSidebarPopulatedStateSnapshot() throws {
        // Add a mock server to the store
        try store.addInstallation(
            name: "Home NAS Server",
            baseURLString: "http://homenas.local:8080",
            apiToken: ""
        )
        
        // Add last snapshot with drives
        let drive = DriveSnapshot(
            id: "disk-sda",
            name: "Seagate BarraCuda",
            model: "ST4000DM004",
            serial: "WFN12345",
            protocolName: "sat",
            capacityBytes: 4000787030016,
            statusCode: 0, // Passed
            temperature: 32,
            powerOnHours: 12500,
            collectorDate: "2026-05-29T23:00:00Z"
        )
        
        let fixedDate = Date(timeIntervalSince1970: 1774828800) // Fixed constant date
        
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 1,
            healthyDrives: 1,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [drive],
            collectedAt: fixedDate
        )
        
        // Inject snapshot and set status to active/passed
        store.installations[0].lastSnapshot = snapshot
        store.installations[0].lastRefreshDate = fixedDate
        
        let view = SidebarView(
            store: store,
            onAddInstallation: {},
            onEditInstallation: {},
            onDeleteInstallation: {}
        )
        
        assertSnapshot(matching: view, named: "SidebarView_PopulatedState_DarkMode", width: 250, height: 400, colorScheme: .dark)
        assertSnapshot(matching: view, named: "SidebarView_PopulatedState_LightMode", width: 250, height: 400, colorScheme: .light)
        
        // Clean up keychain items we created
        for installation in store.installations {
            KeychainHelper.shared.delete(service: InstallationPersistence.installationsKey, account: installation.id.uuidString)
        }
    }
}
