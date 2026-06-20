import Foundation
import UserNotifications
import os

@MainActor
protocol NotificationSettingsProtocol {
    var authorizationStatus: UNAuthorizationStatus { get }
}

extension UNNotificationSettings: NotificationSettingsProtocol {}

@MainActor
protocol NotificationCenterProtocol: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func getNotificationSettings() async -> NotificationSettingsProtocol
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func getNotificationSettings() async -> NotificationSettingsProtocol {
        await self.notificationSettings()
    }
}

@MainActor
private final class DummyNotificationSettings: NotificationSettingsProtocol {
    var authorizationStatus: UNAuthorizationStatus { .denied }
}

@MainActor
private final class DummyNotificationCenter: NotificationCenterProtocol {
    var delegate: UNUserNotificationCenterDelegate?
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
    func getNotificationSettings() async -> NotificationSettingsProtocol {
        DummyNotificationSettings()
    }
    func add(_ request: UNNotificationRequest) async throws {}
}

@MainActor
final class DriveFailureNotificationService {
    static let shared = DriveFailureNotificationService()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScrutinyMonitor", category: "DriveFailureNotificationService")

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenterProtocol
    private let forceAvailableInTests: Bool

    init(
        defaults: UserDefaults = .shared,
        notificationCenter: NotificationCenterProtocol? = nil,
        forceAvailableInTests: Bool = false
    ) {
        self.defaults = defaults
        if let center = notificationCenter {
            self.notificationCenter = center
        } else if Self.isAvailableInCurrentProcess {
            self.notificationCenter = UNUserNotificationCenter.current()
        } else {
            self.notificationCenter = DummyNotificationCenter()
        }
        self.forceAvailableInTests = forceAvailableInTests
    }

    func deliver(_ alerts: [DriveFailureAlert]) {
        guard notificationsEnabled, !alerts.isEmpty else { return }
        guard forceAvailableInTests || Self.isAvailableInCurrentProcess else { return }

        if desktopNotificationsEnabled {
            Task {
                let authorized = await requestDesktopAuthorizationIfNeeded()
                guard authorized else { return }
                for alert in alerts {
                    await deliverDesktopNotification(for: alert)
                }
            }
        }
    }

    static var isAvailableInCurrentProcess: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }

        return Bundle.main.bundleURL.pathExtension == "app"
    }

    var notificationsEnabled: Bool {
        defaults.bool(forKey: AppPreferences.driveFailureNotificationsEnabledKey)
    }

    var desktopNotificationsEnabled: Bool {
        defaults.bool(forKey: AppPreferences.desktopNotificationsEnabledKey)
    }

    private func requestDesktopAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.getNotificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            break
        case .denied:
            return false
        @unknown default:
            return false
        }

        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound])
        } catch {
            // A failed permission request should not interrupt refresh handling.
            return false
        }
    }

    private func deliverDesktopNotification(for alert: DriveFailureAlert) async {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            Self.logger.error("Failed to deliver desktop notification: \(error.localizedDescription)")
        }
    }
}
