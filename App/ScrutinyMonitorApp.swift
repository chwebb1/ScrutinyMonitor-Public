import AppKit
import SwiftUI
import UserNotifications

@main
struct ScrutinyMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Scrutiny Monitor", id: "main") {
            ContentView(store: appDelegate.coordinator.store)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh All") {
                    Task { await appDelegate.coordinator.store.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(appDelegate.coordinator.store.installations.isEmpty)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var coordinator: AppCoordinator = {
        if isRunningHostedTests {
            return AppCoordinator(
                store: Self.makeHostedTestStore(),
                statusBarController: .shared,
                notificationCenter: nil,
                isNotificationServiceAvailable: false
            )
        }

        let isNotificationAvailable = DriveFailureNotificationService.isAvailableInCurrentProcess
        let center = isNotificationAvailable ? UNUserNotificationCenter.current() : nil
        return AppCoordinator(
            store: MonitorStore(),
            statusBarController: .shared,
            notificationCenter: center,
            isNotificationServiceAvailable: isNotificationAvailable
        )
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningHostedTests else { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        coordinator.start()
    }

    private var isRunningHostedTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        Bundle.main.bundleURL.pathExtension != "app"
    }

    private static func makeHostedTestStore() -> MonitorStore {
        let defaults = UserDefaults.ephemeral
        defaults.set(SettingsSyncProvider.selectFolder.rawValue, forKey: SettingsSyncDefaults.providerKey)

        return MonitorStore(
            client: .shared,
            persistence: InstallationPersistence(userDefaults: defaults, migratesLegacyDefaults: false),
            cloudSync: CloudSettingsSynchronizer(defaults: defaults),
            notificationService: DriveFailureNotificationService(defaults: defaults)
        )
    }
}
