import XCTest
import SwiftUI
import ViewInspector
@testable import ScrutinyMonitor

final class MenuBarViewTests: XCTestCase {
    var userDefaults: UserDefaults!
    var store: MonitorStore!
    let suiteName = "com.scrutinymonitor.tests.menubarview"

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
    func testMenuBarLabelEmptyState() throws {
        let view = MenuBarLabel(store: store)

        // When there are no installations, status should be empty, and symbol should be externaldrive
        let image = try view.inspect().find(ViewType.Image.self)
        let name = try image.actualImage().name()
        XCTAssertEqual(name, "externaldrive")
    }

    @MainActor
    func testMenuBarViewEmptyStateLayout() throws {
        let view = MenuBarView(store: store)
        
        // Assert correct title
        let titleText = try view.inspect().find(text: "Scrutiny Monitor")
        XCTAssertNotNil(titleText)

        // Assert empty state configured view
        let emptyStateText = try view.inspect().find(text: "No Installations Configured")
        XCTAssertNotNil(emptyStateText)

        let openAppButton = try view.inspect().find(button: "Open Main App")
        XCTAssertNotNil(openAppButton)
    }

    @MainActor
    func testMenuBarViewWithInstallationsLayout() throws {
        // Let's configure a mock installation and snapshot
        let device = DriveSnapshot(
            id: "disk-1",
            name: "sda",
            model: "Samsung SSD 860",
            serial: "S12345",
            protocolName: "SATA",
            capacityBytes: 500000000000,
            statusCode: 0,
            temperature: 30,
            powerOnHours: 1000,
            collectorDate: "2026-06-01"
        )
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 1,
            healthyDrives: 1,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [device],
            collectedAt: Date()
        )
        
        let installation = ScrutinyInstallation(
            id: UUID(),
            name: "Home NAS",
            baseURL: URL(string: "https://nas.local")!,
            apiToken: Data(),
            lastSnapshot: snapshot,
            lastRefreshDate: Date()
        )
        
        store.installations = [installation]
        
        let view = MenuBarView(store: store)
        
        // Assert installation name is visible
        let instName = try view.inspect().find(text: "Home NAS")
        XCTAssertNotNil(instName)

        // Assert drive details are visible
        let driveName = try view.inspect().find(text: "sda")
        XCTAssertNotNil(driveName)
        
        let driveModel = try view.inspect().find(text: "Samsung SSD 860")
        XCTAssertNotNil(driveModel)

        let tempText = try view.inspect().find(text: "30°C")
        XCTAssertNotNil(tempText)
    }
}

