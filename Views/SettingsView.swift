import AppKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage(AppPreferences.autoRefreshEnabledKey) private var autoRefreshEnabled = false
    @AppStorage(AppPreferences.autoRefreshIntervalKey) private var autoRefreshInterval = AppPreferences.defaultAutoRefreshInterval
    @AppStorage(AppPreferences.driveFailureNotificationsEnabledKey) private var driveFailureNotificationsEnabled = false
    @AppStorage(AppPreferences.desktopNotificationsEnabledKey) private var desktopNotificationsEnabled = false
    @AppStorage(AppPreferences.showMenuBarExtraKey) private var showMenuBarExtra = true
    @State private var desktopAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var selectedProvider: SettingsSyncProvider
    @State private var syncStatus: SettingsSyncStatus
    @State private var webDAVURLString: String
    @State private var webDAVUsername: String
    @State private var webDAVPassword = ""
    @State private var webDAVHasSavedPassword: Bool
    @State private var syncMessage: String?
    @State private var isSyncing = false
    private let synchronizer: CloudSettingsSynchronizer

    private enum WebDAVField: Hashable {
        case url
        case username
        case password
    }
    @FocusState private var focusedWebDAVField: WebDAVField?
    internal let inspection = Inspection<Self>()

    @MainActor
    init(defaults: UserDefaults = .shared, synchronizer: CloudSettingsSynchronizer? = nil) {
        let synchronizer = synchronizer ?? .shared
        self.synchronizer = synchronizer
        _autoRefreshEnabled = AppStorage(wrappedValue: false, AppPreferences.autoRefreshEnabledKey, store: defaults)
        _autoRefreshInterval = AppStorage(wrappedValue: AppPreferences.defaultAutoRefreshInterval, AppPreferences.autoRefreshIntervalKey, store: defaults)
        _driveFailureNotificationsEnabled = AppStorage(wrappedValue: false, AppPreferences.driveFailureNotificationsEnabledKey, store: defaults)
        _desktopNotificationsEnabled = AppStorage(wrappedValue: false, AppPreferences.desktopNotificationsEnabledKey, store: defaults)
        _showMenuBarExtra = AppStorage(wrappedValue: true, AppPreferences.showMenuBarExtraKey, store: defaults)
        _selectedProvider = State(initialValue: synchronizer.selectedProvider)
        _syncStatus = State(initialValue: synchronizer.currentStatus)
        let webDAVConfiguration = synchronizer.webDAVConfiguration()
        _webDAVURLString = State(initialValue: webDAVConfiguration.urlString)
        let username = webDAVConfiguration.secureUsernameData.stringValue ?? ""
        _webDAVUsername = State(initialValue: username)
        _webDAVHasSavedPassword = State(initialValue: webDAVConfiguration.hasPassword)
    }

    var body: some View {
        Form {
            refreshSection
            menuBarSection
            alertsSection
            syncSection
        }
        .formStyle(.grouped)
        .animation(.default, value: syncMessage)
        .onSubmit {
            switch focusedWebDAVField {
            case .url:
                focusedWebDAVField = .username
            case .username:
                focusedWebDAVField = .password
            case .password:
                focusedWebDAVField = nil
                if !webDAVURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    saveWebDAVSettings()
                }
            case nil:
                break
            }
        }
        .animation(.default, value: selectedProvider)
        .padding()
        .frame(width: 620, height: 700)
        .task {
            synchronizer.start()
            refreshSyncState()
            await refreshDesktopAuthorizationStatus()
        }
        .onChange(of: desktopNotificationsEnabled) { _, isEnabled in
            guard isEnabled else { return }
            Task { await requestDesktopAuthorization() }
        }
        .onChange(of: selectedProvider) { _, newProvider in
            syncMessage = nil
            if newProvider == .webDAV {
                focusedWebDAVField = .url
            }
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
}

// MARK: - Sub-views

private extension SettingsView {
    @ViewBuilder
    var refreshSection: some View {
        Section("Refresh") {
            Toggle("Auto-refresh SMART status", isOn: $autoRefreshEnabled)

            LabeledContent("Interval") {
                Picker("Interval", selection: $autoRefreshInterval) {
                    ForEach(AppPreferences.refreshIntervals) { option in
                        Text(option.title)
                            .tag(option.seconds)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Interval")
            }
            .disabled(!autoRefreshEnabled)
            .help(autoRefreshEnabled ? "Select auto-refresh interval" : "Enable auto-refresh to change interval")
        }
    }

    @ViewBuilder
    var menuBarSection: some View {
        Section("Menu Bar") {
            Toggle("Show menu bar item", isOn: $showMenuBarExtra)
                .onChange(of: showMenuBarExtra) { _, isVisible in
                    StatusBarController.shared.setVisible(isVisible)
                }
                .help("Toggle whether the Scrutiny Monitor status menu bar item is visible.")
        }
    }

    @ViewBuilder
    var alertsSection: some View {
        Section("Drive Failure Alerts") {
            Toggle("Notify when a drive begins failing", isOn: $driveFailureNotificationsEnabled)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Desktop notifications", isOn: $desktopNotificationsEnabled)
                    .disabled(!driveFailureNotificationsEnabled)
                    .help(driveFailureNotificationsEnabled ? "Toggle desktop notifications" : "Enable drive failure alerts first")

                HStack {
                    Text(desktopAuthorizationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Allow") {
                        Task { await requestDesktopAuthorization() }
                    }
                    .disabled(
                        !DriveFailureNotificationService.isAvailableInCurrentProcess ||
                        !driveFailureNotificationsEnabled ||
                        !desktopNotificationsEnabled ||
                        desktopAuthorizationStatus == .authorized
                    )
                    .help(desktopAuthorizationHelpText)
                }
            }

            Text("To receive alerts via Email, SMS, Webhooks, and more, configure notifications natively on your Scrutiny server.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var syncSection: some View {
        Section("Sync") {
            LabeledContent("Location") {
                Picker("Location", selection: syncProviderBinding) {
                    ForEach(SettingsSyncProvider.allCases) { provider in
                        Label(provider.displayName, systemImage: provider.symbolName)
                            .tag(provider)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Location")
            }

            Label {
                Text(syncStatus.message)
            } icon: {
                Image(systemName: syncStatus.isAvailable ? selectedProvider.symbolName : "exclamationmark.triangle")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(syncStatus.isAvailable ? .primary : .secondary)

            if let lastSyncDate = syncStatus.lastSyncDate {
                Text("Last synced \(lastSyncDate.formatted(date: .abbreviated, time: .shortened)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if selectedProvider.usesFolder {
                LabeledContent("Folder") {
                    HStack {
                        Text(synchronizer.folderPath(for: selectedProvider) ?? "No folder selected")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)

                        Button {
                            chooseSyncFolder()
                        } label: {
                            Label("Choose Folder", systemImage: "folder.badge.plus")
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Choose sync folder")
                        .help("Choose sync folder")
                    }
                }
            }

            if selectedProvider == .webDAV {
                webDAVFields
            }

            HStack {
                Button {
                    Task { await syncNow() }
                } label: {
                    if isSyncing {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Syncing")
                            Text("Syncing...")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Syncing")
                    } else {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(!syncStatus.isConfigured || isSyncing)
                .help(!syncStatus.isConfigured ? "Configure sync to enable manual sync" : (isSyncing ? "Syncing" : "Force sync settings now"))

                if let syncMessage {
                    Text(syncMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Installation names, URLs, and preferences sync automatically. API tokens stay in Keychain on each Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var webDAVFields: some View {
        LabeledContent("Folder URL *") {
            TextField("Folder URL *", text: $webDAVURLString, prompt: Text("https://example.com/dav/settings"))
                .focused($focusedWebDAVField, equals: .url)
                .textContentType(.URL)
                .labelsHidden()
                .onChange(of: webDAVURLString) { _, newValue in
                    syncMessage = nil
                    if newValue.count > 1024 { webDAVURLString = String(newValue.prefix(1024)) }
                }
        }

        LabeledContent("Username") {
            TextField("Username", text: $webDAVUsername, prompt: Text("Optional"))
                .focused($focusedWebDAVField, equals: .username)
                .textContentType(.username)
                .labelsHidden()
                .onChange(of: webDAVUsername) { _, newValue in
                    syncMessage = nil
                    let filtered = String(newValue.prefix(100)).removingControlCharacters()
                    if webDAVUsername != filtered { webDAVUsername = filtered }
                }
        }

        LabeledContent("Password") {
            HStack {
                SecureField("Password", text: $webDAVPassword, prompt: Text(webDAVHasSavedPassword ? "Saved password" : "Optional"))
                    .focused($focusedWebDAVField, equals: .password)
                    .textContentType(.password)
                    .labelsHidden()
                    .onChange(of: webDAVPassword) { _, newValue in
                        syncMessage = nil
                        let filtered = String(newValue.prefix(4096)).removingControlCharacters()
                        if webDAVPassword != filtered { webDAVPassword = filtered }
                    }
                if webDAVHasSavedPassword {
                    Button(role: .destructive) {
                        webDAVPassword = ""
                        webDAVHasSavedPassword = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear saved password")
                    .help("Clear saved password")
                }
            }
        }

        Button {
            saveWebDAVSettings()
        } label: {
            Label("Save WebDAV Settings", systemImage: "checkmark.circle")
        }
        .disabled(webDAVURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .help(webDAVURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A valid URL is required" : "Save WebDAV Settings")
        .id("saveWebDAVButton")
    }
}

// MARK: - Actions & Helpers

private extension SettingsView {
    @MainActor var syncProviderBinding: Binding<SettingsSyncProvider> {
        Binding {
            selectedProvider
        } set: { provider in
            selectedProvider = provider
            synchronizer.selectedProvider = provider
            refreshSyncState()
        }
    }

    @MainActor var desktopAuthorizationText: String {
        guard DriveFailureNotificationService.isAvailableInCurrentProcess else {
            return "Desktop notifications require launching the packaged app."
        }

        return switch desktopAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            "Allowed in System Settings."
        case .denied:
            "Denied in System Settings."
        case .notDetermined:
            "Permission has not been requested."
        @unknown default:
            "Permission status is unknown."
        }
    }

    @MainActor var desktopAuthorizationHelpText: String {
        if !DriveFailureNotificationService.isAvailableInCurrentProcess {
            return "Launch the packaged app to enable desktop notifications"
        }

        if !driveFailureNotificationsEnabled {
            return "Enable drive failure alerts first"
        }

        if !desktopNotificationsEnabled {
            return "Enable desktop notifications first"
        }

        if desktopAuthorizationStatus == .authorized {
            return "Permission already granted"
        }

        return "Request notification permission"
    }

    func requestDesktopAuthorization() async {
        guard DriveFailureNotificationService.isAvailableInCurrentProcess else { return }

        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            // The status text will remain accurate after refreshing below.
        }

        await refreshDesktopAuthorizationStatus()
    }

    func refreshDesktopAuthorizationStatus() async {
        guard DriveFailureNotificationService.isAvailableInCurrentProcess else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        desktopAuthorizationStatus = settings.authorizationStatus
    }

    @MainActor func refreshSyncState() {
        selectedProvider = synchronizer.selectedProvider
        syncStatus = synchronizer.currentStatus

        let webDAVConfiguration = synchronizer.webDAVConfiguration()
        webDAVURLString = webDAVConfiguration.urlString
        webDAVUsername = webDAVConfiguration.secureUsernameData.stringValue ?? ""
        webDAVHasSavedPassword = webDAVConfiguration.hasPassword
    }

    @MainActor func chooseSyncFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose the \(selectedProvider.displayName) folder to sync Scrutiny Monitor settings."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try synchronizer.setFolderURL(url, for: selectedProvider)
            syncMessage = "Folder saved."
            refreshSyncState()
        } catch {
            syncMessage = error.secureDescription
        }
    }

    @MainActor func saveWebDAVSettings() {
        do {
            let password = webDAVPassword.isEmpty && webDAVHasSavedPassword ? nil : webDAVPassword
            try synchronizer.setWebDAVConfiguration(
                urlString: webDAVURLString,
                username: webDAVUsername,
                password: password
            )
            webDAVPassword = ""
            syncMessage = "WebDAV saved."
            refreshSyncState()
        } catch {
            syncMessage = error.secureDescription
        }
    }

    @MainActor func syncNow() async {
        isSyncing = true
        await synchronizer.syncNow()
        isSyncing = false
        syncMessage = "Sync complete."
        refreshSyncState()
    }
}
