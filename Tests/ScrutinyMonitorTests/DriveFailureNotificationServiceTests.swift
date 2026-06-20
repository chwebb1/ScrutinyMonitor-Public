import XCTest
import UserNotifications
@testable import ScrutinyMonitor

@MainActor
final class MockNotificationSettings: NotificationSettingsProtocol {
    var authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }
}

@MainActor
final class MockNotificationCenter: @MainActor NotificationCenterProtocol {
    var delegate: UNUserNotificationCenterDelegate?
    var addedRequests = [UNNotificationRequest]()
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var requestAuthorizationCallCount = 0
    var onAuthorizationRequested: (() -> Void)?
    var onAddAttempt: ((UNNotificationRequest) -> Void)?
    var onAdd: ((UNNotificationRequest) -> Void)?
    var requestAuthorizationError: Error?
    var addError: Error?
    var shouldApproveAuthorization = true

    var didThrowAuthorizationError = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        onAuthorizationRequested?()
        if let error = requestAuthorizationError {
            didThrowAuthorizationError = true
            throw error
        }
        return shouldApproveAuthorization
    }

    func getNotificationSettings() async -> NotificationSettingsProtocol {
        MockNotificationSettings(authorizationStatus: authorizationStatus)
    }

    func add(_ request: UNNotificationRequest) async throws {
        onAddAttempt?(request)
        if let error = addError {
            throw error
        }
        addedRequests.append(request)
        onAdd?(request)
    }
}

@MainActor
final class DriveFailureNotificationServiceTests: XCTestCase {
    var userDefaults: UserDefaults!
    var mockCenter: MockNotificationCenter!
    var service: DriveFailureNotificationService!
    let suiteName = "com.scrutinymonitor.tests.notificationtests"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        mockCenter = MockNotificationCenter()
        service = DriveFailureNotificationService(
            defaults: userDefaults,
            notificationCenter: mockCenter,
            forceAvailableInTests: true
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        mockCenter = nil
        service = nil
        super.tearDown()
    }

    func testNotificationsDisabledByDefault() {
        XCTAssertFalse(service.notificationsEnabled)
    }

    func testNotificationsEnabledWhenSet() {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        XCTAssertTrue(service.notificationsEnabled)
    }

    func testDesktopNotificationsDisabledByDefault() {
        XCTAssertFalse(service.desktopNotificationsEnabled)
    }

    func testDesktopNotificationsEnabledWhenSet() {
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)
        XCTAssertTrue(service.desktopNotificationsEnabled)
    }

    func testDeliverSchedulesNotificationRequest() async throws {
        // Enable alerts & desktop notifications
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)

        let drive = DriveSnapshot(
            id: "disk-1",
            name: "Main Disk",
            model: "Model",
            serial: "SERIAL123",
            protocolName: "sat",
            capacityBytes: nil,
            statusCode: 2, // Failed
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )
        let alert = DriveFailureAlert(
            installationName: "Home NAS",
            drive: drive,
            previousStatus: .passed
        )
        let notificationAdded = expectation(description: "Notification request added")
        mockCenter.onAdd = { _ in notificationAdded.fulfill() }

        service.deliver([alert])

        await fulfillment(of: [notificationAdded], timeout: 1.0)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        if let request = mockCenter.addedRequests.first {
            XCTAssertEqual(request.identifier, "Home NAS-disk-1-failed")
            XCTAssertEqual(request.content.title, "Drive Failure")
            XCTAssertEqual(request.content.body, "Main Disk on Home NAS is now failed.")
        }
    }

    func testDeliverRequestsAuthorizationWhenNotDetermined() async throws {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)

        // Simulate authorization not yet determined
        mockCenter.authorizationStatus = .notDetermined

        let drive = DriveSnapshot(
            id: "disk-1",
            name: "Main Disk",
            model: "Model",
            serial: "SERIAL123",
            protocolName: "sat",
            capacityBytes: nil,
            statusCode: 2,
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )
        let alert = DriveFailureAlert(installationName: "Home NAS", drive: drive, previousStatus: .passed)
        let authorizationRequested = expectation(description: "Authorization requested")
        let notificationAdded = expectation(description: "Notification request added")
        mockCenter.onAuthorizationRequested = { authorizationRequested.fulfill() }
        mockCenter.onAdd = { _ in notificationAdded.fulfill() }

        service.deliver([alert])

        await fulfillment(of: [authorizationRequested, notificationAdded], timeout: 1.0)

        XCTAssertEqual(mockCenter.requestAuthorizationCallCount, 1)
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
    }

    func testDeliverDoesNotRequestAuthorizationWhenAlreadyAuthorized() async throws {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)
        
        // Simulate already authorized
        mockCenter.authorizationStatus = .authorized

        let drive = DriveSnapshot(
            id: "disk-1",
            name: "Main Disk",
            model: "Model",
            serial: "SERIAL123",
            protocolName: "sat",
            capacityBytes: nil,
            statusCode: 2,
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )
        let alert = DriveFailureAlert(installationName: "Home NAS", drive: drive, previousStatus: .passed)
        let notificationAdded = expectation(description: "Notification request added")
        mockCenter.onAdd = { _ in notificationAdded.fulfill() }

        service.deliver([alert])

        await fulfillment(of: [notificationAdded], timeout: 1.0)

        XCTAssertEqual(mockCenter.requestAuthorizationCallCount, 0)
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
    }

    func testIsAvailableInCurrentProcess() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let expected = !isRunningTests && Bundle.main.bundleURL.pathExtension == "app"
        XCTAssertEqual(DriveFailureNotificationService.isAvailableInCurrentProcess, expected)
    }

    func testDeliverHandlesAddErrorGracefully() async throws {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)

        struct DummyError: Error {}
        mockCenter.addError = DummyError()

        let drive = DriveSnapshot(
            id: "disk-1",
            name: "Main Disk",
            model: "Model",
            serial: "SERIAL123",
            protocolName: "sat",
            capacityBytes: nil,
            statusCode: 2,
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )
        let alert = DriveFailureAlert(installationName: "Home NAS", drive: drive, previousStatus: .passed)
        let addAttempted = expectation(description: "Notification add attempted")
        mockCenter.onAddAttempt = { _ in addAttempted.fulfill() }

        service.deliver([alert])

        await fulfillment(of: [addAttempted], timeout: 1.0)

        XCTAssertEqual(mockCenter.addedRequests.count, 0)
    }

    @MainActor
    func testDeliverMultipleAlerts() async throws {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)

        let drive1 = DriveSnapshot(id: "disk-1", name: "Disk 1", model: "Model", serial: "S1", protocolName: "sat", capacityBytes: nil, statusCode: 2, temperature: nil, powerOnHours: nil, collectorDate: nil)
        let drive2 = DriveSnapshot(id: "disk-2", name: "Disk 2", model: "Model", serial: "S2", protocolName: "sat", capacityBytes: nil, statusCode: 2, temperature: nil, powerOnHours: nil, collectorDate: nil)

        let alert1 = DriveFailureAlert(installationName: "NAS", drive: drive1, previousStatus: .passed)
        let alert2 = DriveFailureAlert(installationName: "NAS", drive: drive2, previousStatus: .passed)
        let notificationsAdded = expectation(description: "Both notification requests added")
        notificationsAdded.expectedFulfillmentCount = 2
        mockCenter.onAdd = { _ in notificationsAdded.fulfill() }

        service.deliver([alert1, alert2])

        await fulfillment(of: [notificationsAdded], timeout: 1.0)

        XCTAssertEqual(mockCenter.addedRequests.count, 2)
    }

    @MainActor
    func testDeliverRecoveryAlert() async throws {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)

        let drive = DriveSnapshot(id: "disk-1", name: "Main Disk", model: "Model", serial: "SERIAL123", protocolName: "sat", capacityBytes: nil, statusCode: 0, temperature: nil, powerOnHours: nil, collectorDate: nil)
        let alert = DriveFailureAlert(installationName: "Home NAS", drive: drive, previousStatus: .failed)
        let notificationAdded = expectation(description: "Notification request added")
        mockCenter.onAdd = { _ in notificationAdded.fulfill() }

        service.deliver([alert])

        await fulfillment(of: [notificationAdded], timeout: 1.0)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        if let request = mockCenter.addedRequests.first {
            XCTAssertEqual(request.identifier, "Home NAS-disk-1-passed")
            XCTAssertEqual(request.content.title, alert.title)
            XCTAssertEqual(request.content.body, alert.message)
            XCTAssertEqual(alert.previousStatus, .failed)
            XCTAssertFalse(alert.drive.status.isAtRisk)
        }
    }

    @MainActor
    func testDeliverHandlesAuthorizationErrorGracefully() async throws {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)

        mockCenter.authorizationStatus = .notDetermined
        struct DummyError: Error {}
        mockCenter.requestAuthorizationError = DummyError()

        let drive = DriveSnapshot(
            id: "disk-1",
            name: "Main Disk",
            model: "Model",
            serial: "SERIAL123",
            protocolName: "sat",
            capacityBytes: nil,
            statusCode: 2,
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )
        let alert = DriveFailureAlert(installationName: "Home NAS", drive: drive, previousStatus: .passed)
        let authorizationRequested = expectation(description: "Authorization requested")
        mockCenter.onAuthorizationRequested = { authorizationRequested.fulfill() }

        let addAttempted = expectation(description: "Add attempt should not occur")
        addAttempted.isInverted = true
        mockCenter.onAddAttempt = { _ in addAttempted.fulfill() }

        service.deliver([alert])

        // Wait to ensure authorization is requested, and that no add attempt is made during this window
        await fulfillment(of: [authorizationRequested, addAttempted], timeout: 1.0)

        XCTAssertEqual(mockCenter.addedRequests.count, 0)
        XCTAssertEqual(mockCenter.requestAuthorizationCallCount, 1)
        XCTAssertTrue(mockCenter.didThrowAuthorizationError, "Mock should have thrown the injected error")
        XCTAssertEqual(mockCenter.addedRequests.count, 0, "Delivery should be skipped if authorization fails")

    }

    @MainActor
    func testDeliverAuthorizationDenied() async throws {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)

        mockCenter.authorizationStatus = .notDetermined
        mockCenter.shouldApproveAuthorization = false

        let drive = DriveSnapshot(
            id: "disk-1",
            name: "Main Disk",
            model: "Model",
            serial: "SERIAL123",
            protocolName: "sat",
            capacityBytes: nil,
            statusCode: 2,
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )
        let alert = DriveFailureAlert(installationName: "Home NAS", drive: drive, previousStatus: .passed)
        let authorizationRequested = expectation(description: "Authorization requested")
        mockCenter.onAuthorizationRequested = { authorizationRequested.fulfill() }

        let addAttempted = expectation(description: "Add attempt should not occur")
        addAttempted.isInverted = true
        mockCenter.onAddAttempt = { _ in addAttempted.fulfill() }

        service.deliver([alert])

        await fulfillment(of: [authorizationRequested, addAttempted], timeout: 1.0)

        // Ensure no requests were added since authorization was explicitly denied.
        XCTAssertEqual(mockCenter.addedRequests.count, 0)
    }

    @MainActor
    func testDeliverWithPreDeniedAuthorization() async throws {
        userDefaults.set(true, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        userDefaults.set(true, forKey: AppPreferences.desktopNotificationsEnabledKey)

        mockCenter.authorizationStatus = .denied

        let drive = DriveSnapshot(
            id: "disk-1",
            name: "Main Disk",
            model: "Model",
            serial: "SERIAL123",
            protocolName: "sat",
            capacityBytes: nil,
            statusCode: 2,
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )
        let alert = DriveFailureAlert(installationName: "Home NAS", drive: drive, previousStatus: .passed)

        let addAttempted = expectation(description: "Add attempt should not occur")
        addAttempted.isInverted = true
        mockCenter.onAddAttempt = { _ in addAttempted.fulfill() }

        service.deliver([alert])

        await fulfillment(of: [addAttempted], timeout: 1.0)

        XCTAssertEqual(mockCenter.addedRequests.count, 0)
        XCTAssertEqual(mockCenter.requestAuthorizationCallCount, 0)
    }
}
