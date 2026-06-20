import AppKit
import UserNotifications
import SwiftUI

@MainActor
final class AppCoordinator: NSObject, UNUserNotificationCenterDelegate {
    let store: MonitorStore
    let statusBarController: StatusBarController
    private var notificationCenter: NotificationCenterProtocol?
    let isNotificationServiceAvailable: Bool

    init(
        store: MonitorStore,
        statusBarController: StatusBarController,
        notificationCenter: NotificationCenterProtocol? = nil,
        isNotificationServiceAvailable: Bool
    ) {
        self.store = store
        self.statusBarController = statusBarController
        self.notificationCenter = notificationCenter
        self.isNotificationServiceAvailable = isNotificationServiceAvailable
        super.init()
    }

    func start() {
        if isNotificationServiceAvailable {
            notificationCenter?.delegate = self
        }
        
        statusBarController.start(store: store)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
