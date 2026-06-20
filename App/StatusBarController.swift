import AppKit
import Observation
import SwiftUI

protocol AppWorkspace: AnyObject {
    func activate(ignoringOtherApps flag: Bool)
    var windows: [NSWindow] { get }
    var mainMenu: NSMenu? { get }
    @discardableResult func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool
}

extension NSApplication: AppWorkspace {}

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
    static let shared = StatusBarController()

    private var injectedWorkspace: AppWorkspace?
    var workspace: AppWorkspace {
        get {
            injectedWorkspace ?? NSApplication.shared
        }
        set {
            injectedWorkspace = newValue
        }
    }

    override init() {
        super.init()
    }

    init(workspace: AppWorkspace) {
        super.init()
        self.workspace = workspace
    }
    internal var statusItem: NSStatusItem?
    private var defaultsObserver: NSObjectProtocol?
    internal var store: MonitorStore?
    internal var driveDetailWindowControllers: [String: NSWindowController] = [:]

    internal lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        return popover
    }()

    func start(store: MonitorStore) {
        guard self.store == nil else { return }

        self.store = store
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateVisibility()
            }
        }

        updateVisibility()
        observeStatus()
    }

    func setVisible(_ isVisible: Bool) {
        updateVisibility(isVisible: isVisible)
    }

    func openMainWindow() {
        popover.performClose(nil)
        workspace.activate(ignoringOtherApps: true)

        if let window = workspace.windows.first(where: isMainWindow) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        performMenuItem(inMenu: "File") { item in
            item.title.hasPrefix("New ") && item.title.hasSuffix(" Window")
        }
    }

    func openSettings() {
        popover.performClose(nil)
        workspace.activate(ignoringOtherApps: true)
        performMenuItem(titled: "Settings...", in: workspace.mainMenu?.items.first?.submenu)
    }

    func openInstallation(_ installation: ScrutinyInstallation) {
        store?.selection = .installation(installation.id)
        openMainWindow()
    }

    func openDriveDetails(installation: ScrutinyInstallation, drive: DriveSnapshot) {
        popover.performClose(nil)
        workspace.activate(ignoringOtherApps: true)

        let key = "\(installation.id.uuidString)-\(drive.id)"
        if let window = driveDetailWindowControllers[key]?.window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(drive.name) SMART Details"
        window.center()
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: DriveDetailView(installation: installation, drive: drive) { [weak self] in
                self?.closeDriveDetails(key: key)
            }
        )

        let windowController = NSWindowController(window: window)
        driveDetailWindowControllers[key] = windowController
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    private func updateVisibility() {
        let defaults = UserDefaults.standard
        let isVisible = defaults.object(forKey: AppPreferences.showMenuBarExtraKey) as? Bool ?? true
        updateVisibility(isVisible: isVisible)
    }

    private func updateVisibility(isVisible: Bool) {
        if isVisible {
            installStatusItemIfNeeded()
        } else {
            popover.performClose(nil)
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItem = nil
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil, let store else { return }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.toolTip = "Scrutiny Monitor"
        popover.contentViewController = NSHostingController(rootView: MenuBarView(store: store))
        self.statusItem = statusItem
        updateStatusIcon()
    }

    private func observeStatus() {
        guard let store else { return }

        withObservationTracking {
            for installation in store.installations {
                _ = installation.status
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateStatusIcon()
                self?.observeStatus()
            }
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        button.image = NSImage(
            systemSymbolName: statusSymbolName,
            accessibilityDescription: "Scrutiny Monitor"
        )
    }

    private func isMainWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue.hasPrefix("main-AppWindow-") == true
    }

    private func performMenuItem(titled title: String, inMenu menuTitle: String) {
        performMenuItem(titled: title, in: workspace.mainMenu?.item(withTitle: menuTitle)?.submenu)
    }

    private func performMenuItem(inMenu menuTitle: String, matching predicate: (NSMenuItem) -> Bool) {
        performMenuItem(in: workspace.mainMenu?.item(withTitle: menuTitle)?.submenu, matching: predicate)
    }

    private func performMenuItem(titled title: String, in menu: NSMenu?) {
        performMenuItem(in: menu) { item in
            item.title == title || item.title == title.replacingOccurrences(of: "...", with: "…")
        }
    }

    private func performMenuItem(in menu: NSMenu?, matching predicate: (NSMenuItem) -> Bool) {
        guard let item = menu?.items.first(where: predicate),
              let action = item.action else {
            return
        }

        workspace.sendAction(action, to: item.target, from: item)
    }

    private func closeDriveDetails(key: String) {
        driveDetailWindowControllers.removeValue(forKey: key)?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow,
              let key = driveDetailWindowControllers.first(where: { $0.value.window === closedWindow })?.key else {
            return
        }

        driveDetailWindowControllers.removeValue(forKey: key)
    }

    public var statusSymbolName: String {
        store?.overallStatus.statusSymbolName ?? "externaldrive"
    }
}
