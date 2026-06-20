import XCTest
import UserNotifications
@testable import ScrutinyMonitor

@MainActor
final class AppCoordinatorTests: XCTestCase {
    var mockCenter: MockNotificationCenter!
    var store: MonitorStore!
    var statusBarController: StatusBarController!
    var userDefaults: UserDefaults!
    let suiteName = "com.scrutinymonitor.tests.appcoordinator"
    
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)

        mockCenter = MockNotificationCenter()
        store = MonitorStore(
            client: .shared,
            persistence: InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: userDefaults),
            notificationService: DriveFailureNotificationService(defaults: userDefaults)
        )
        statusBarController = StatusBarController()
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        mockCenter = nil
        store = nil
        statusBarController = nil
        userDefaults = nil
        super.tearDown()
    }
    
    func testStartRegistersNotificationDelegateIfAvailable() {
        let coordinator = AppCoordinator(
            store: store,
            statusBarController: statusBarController,
            notificationCenter: mockCenter,
            isNotificationServiceAvailable: true
        )
        
        XCTAssertNil(mockCenter.delegate)
        coordinator.start()
        
        XCTAssertTrue(mockCenter.delegate === coordinator)
        XCTAssertTrue(statusBarController.store === store)
    }
    
    func testStartDoesNotRegisterDelegateIfNotAvailable() {
        let coordinator = AppCoordinator(
            store: store,
            statusBarController: statusBarController,
            notificationCenter: mockCenter,
            isNotificationServiceAvailable: false
        )
        
        XCTAssertNil(mockCenter.delegate)
        coordinator.start()
        
        XCTAssertNil(mockCenter.delegate)
        XCTAssertTrue(statusBarController.store === store)
    }
}
