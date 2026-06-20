import Foundation

struct InstallationSyncRecord: Codable, Equatable {
    var id: UUID
    var name: String
    var baseURL: URL
    var updatedAt: Date

    init(id: UUID, name: String, baseURL: URL, updatedAt: Date) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.updatedAt = updatedAt
    }

    init(installation: ScrutinyInstallation, updatedAt: Date) {
        self.init(
            id: installation.id,
            name: installation.name,
            baseURL: installation.baseURL,
            updatedAt: updatedAt
        )
    }

    func makeInstallation(apiToken: Data) -> ScrutinyInstallation {
        ScrutinyInstallation(
            id: id,
            name: name,
            baseURL: baseURL,
            apiToken: apiToken
        )
    }

    func apply(to installation: inout ScrutinyInstallation) -> Bool {
        var didChange = false

        if installation.name != name {
            installation.name = name
            didChange = true
        }

        if installation.baseURL != baseURL {
            installation.baseURL = baseURL
            didChange = true
        }

        if didChange {
            installation.lastError = nil
        }

        return didChange
    }
}

struct InstallationSyncDeletion: Codable, Equatable {
    var id: UUID
    var deletedAt: Date
}

struct InstallationSyncEnvelope: Codable, Equatable {
    static let currentVersion = 1

    var version = Self.currentVersion
    var records: [InstallationSyncRecord]
    var deletions: [InstallationSyncDeletion]
    var updatedAt: Date

    init(
        version: Int = Self.currentVersion,
        records: [InstallationSyncRecord] = [],
        deletions: [InstallationSyncDeletion] = [],
        updatedAt: Date = Date()
    ) {
        self.version = version
        self.records = records
        self.deletions = deletions
        self.updatedAt = updatedAt
    }
}

struct InstallationSyncMetadata: Codable, Equatable {
    var recordUpdates: [UUID: Date] = [:]
    var deletions: [UUID: Date] = [:]
}

struct InstallationSyncMergeResult {
    var installations: [ScrutinyInstallation]
    var metadata: InstallationSyncMetadata
    var changedInstallations: Bool
    var deletedTokenIDs: [UUID]
    var needsCloudPublish: Bool
}

enum InstallationSyncEngine {
    private struct MergeState {
        var mergedMetadata: InstallationSyncMetadata
        var changedInstallations = false
        var deletedTokenIDs: [UUID] = []
        var needsCloudPublish = false
        var installationsDict = [UUID: ScrutinyInstallation]()
        var orderedIDs = [UUID]()

        init(metadata: InstallationSyncMetadata, localInstallations: [ScrutinyInstallation]) {
            self.mergedMetadata = metadata
            // ⚡ Bolt: Convert array to dictionary + ordered ID array to replace
            // O(N) firstIndex lookups in loops, dropping complexity from O(N^2) to O(N).
            for installation in localInstallations {
                self.installationsDict[installation.id] = installation
                self.orderedIDs.append(installation.id)
            }
        }

        mutating func processDeletions(deletionsByID: [UUID: Date], recordsByID: [UUID: InstallationSyncRecord]) {
            for (id, deletedAt) in deletionsByID {
                let localUpdatedAt = mergedMetadata.recordUpdates[id] ?? .distantPast
                let cloudUpdatedAt = recordsByID[id]?.updatedAt ?? .distantPast
                guard deletedAt >= localUpdatedAt, deletedAt >= cloudUpdatedAt else {
                    needsCloudPublish = true
                    continue
                }

                if installationsDict[id] != nil {
                    installationsDict.removeValue(forKey: id)
                    changedInstallations = true
                    deletedTokenIDs.append(id)
                }

                mergedMetadata.recordUpdates.removeValue(forKey: id)
                mergedMetadata.deletions[id] = max(mergedMetadata.deletions[id] ?? .distantPast, deletedAt)
            }
        }

        mutating func processRecords(
            envelopeRecords: [InstallationSyncRecord],
            recordsByID: [UUID: InstallationSyncRecord],
            deletionsByID: [UUID: Date],
            tokenProvider: (UUID) -> Data?
        ) {
            var seenIDs = Set<UUID>()
            for envelopeRecord in envelopeRecords {
                guard seenIDs.insert(envelopeRecord.id).inserted else { continue }

                guard let record = recordsByID[envelopeRecord.id] else { continue }

                let deletedAt = max(
                    mergedMetadata.deletions[record.id] ?? .distantPast,
                    deletionsByID[record.id] ?? .distantPast
                )
                guard record.updatedAt > deletedAt else { continue }

                if !updateExistingInstallation(forID: record.id, with: record) {
                    addNewInstallation(with: record, tokenProvider: tokenProvider)
                }
            }
        }

        private mutating func updateExistingInstallation(forID id: UUID, with record: InstallationSyncRecord) -> Bool {
            guard var installation = installationsDict[id] else { return false }
            let localUpdatedAt = mergedMetadata.recordUpdates[id] ?? .distantPast

            if record.updatedAt > localUpdatedAt {
                if record.apply(to: &installation) {
                    installationsDict[id] = installation
                    changedInstallations = true
                }
                mergedMetadata.recordUpdates[id] = record.updatedAt
                mergedMetadata.deletions.removeValue(forKey: id)
            } else if localUpdatedAt > record.updatedAt {
                needsCloudPublish = true
            }
            return true
        }

        private mutating func addNewInstallation(with record: InstallationSyncRecord, tokenProvider: (UUID) -> Data?) {
            let newInstallation = record.makeInstallation(apiToken: tokenProvider(record.id) ?? Data())
            installationsDict[record.id] = newInstallation
            if !orderedIDs.contains(record.id) {
                orderedIDs.append(record.id)
            }
            mergedMetadata.recordUpdates[record.id] = record.updatedAt
            mergedMetadata.deletions.removeValue(forKey: record.id)
            changedInstallations = true
        }

        func reconstructInstallations() -> [ScrutinyInstallation] {
            // Reconstruct exact array preserving order
            var mergedInstallations = [ScrutinyInstallation]()
            mergedInstallations.reserveCapacity(installationsDict.count)
            var seenIDs = Set<UUID>()
            for id in orderedIDs {
                if !seenIDs.contains(id), let installation = installationsDict[id] {
                    mergedInstallations.append(installation)
                    seenIDs.insert(id)
                }
            }
            return mergedInstallations
        }

        mutating func processNeedsPublish(
            mergedInstallations: [ScrutinyInstallation],
            recordsByID: [UUID: InstallationSyncRecord],
            deletionsByID: [UUID: Date],
            now: Date
        ) {
            for installation in mergedInstallations {
                let localUpdatedAt = mergedMetadata.recordUpdates[installation.id]
                let cloudRecord = recordsByID[installation.id]
                let cloudDeletedAt = deletionsByID[installation.id] ?? .distantPast

                if localUpdatedAt == nil, cloudRecord == nil, cloudDeletedAt == .distantPast {
                    mergedMetadata.recordUpdates[installation.id] = now
                    needsCloudPublish = true
                } else if let localUpdatedAt, localUpdatedAt > (cloudRecord?.updatedAt ?? cloudDeletedAt) {
                    needsCloudPublish = true
                }
            }
        }
    }

    static func merge(
        localInstallations: [ScrutinyInstallation],
        envelope: InstallationSyncEnvelope,
        metadata: InstallationSyncMetadata,
        now: Date,
        tokenProvider: (UUID) -> Data?
    ) -> InstallationSyncMergeResult {
        var state = MergeState(metadata: metadata, localInstallations: localInstallations)
        let recordsByID = latestRecordsByID(envelope.records)
        let deletionsByID = latestDeletionsByID(envelope.deletions)

        state.processDeletions(deletionsByID: deletionsByID, recordsByID: recordsByID)
        state.processRecords(envelopeRecords: envelope.records, recordsByID: recordsByID, deletionsByID: deletionsByID, tokenProvider: tokenProvider)

        let mergedInstallations = state.reconstructInstallations()
        state.processNeedsPublish(
            mergedInstallations: mergedInstallations,
            recordsByID: recordsByID,
            deletionsByID: deletionsByID,
            now: now
        )

        return InstallationSyncMergeResult(
            installations: mergedInstallations,
            metadata: state.mergedMetadata,
            changedInstallations: state.changedInstallations,
            deletedTokenIDs: state.deletedTokenIDs,
            needsCloudPublish: state.needsCloudPublish
        )
    }

    static func publishingEnvelope(
        installations: [ScrutinyInstallation],
        metadata: InstallationSyncMetadata,
        existingEnvelope: InstallationSyncEnvelope?,
        now: Date
    ) -> InstallationSyncEnvelope {
        var recordsByID = latestRecordsByID(existingEnvelope?.records ?? [])
        var deletionsByID = latestDeletionsByID(existingEnvelope?.deletions ?? [])

        for (id, deletedAt) in metadata.deletions {
            deletionsByID[id] = max(deletionsByID[id] ?? .distantPast, deletedAt)

            if let record = recordsByID[id], deletedAt >= record.updatedAt {
                recordsByID.removeValue(forKey: id)
            }
        }

        for installation in installations {
            let updatedAt = metadata.recordUpdates[installation.id] ?? now
            let deletedAt = deletionsByID[installation.id] ?? .distantPast
            guard updatedAt > deletedAt else { continue }

            recordsByID[installation.id] = InstallationSyncRecord(
                installation: installation,
                updatedAt: updatedAt
            )
            deletionsByID.removeValue(forKey: installation.id)
        }

        var deletions = [InstallationSyncDeletion]()
        deletions.reserveCapacity(deletionsByID.count)
        for (id, deletedAt) in deletionsByID {
            deletions.append(InstallationSyncDeletion(id: id, deletedAt: deletedAt))
        }
        deletions.sort { $0.deletedAt > $1.deletedAt }

        return InstallationSyncEnvelope(
            records: recordsByID.values.sorted(by: syncRecordSort),
            deletions: deletions,
            updatedAt: now
        )
    }

    private static func latestRecordsByID(_ records: [InstallationSyncRecord]) -> [UUID: InstallationSyncRecord] {
        var result = [UUID: InstallationSyncRecord]()
        result.reserveCapacity(records.count)
        for record in records {
            if let existing = result[record.id] {
                if record.updatedAt > existing.updatedAt {
                    result[record.id] = record
                }
            } else {
                result[record.id] = record
            }
        }
        return result
    }

    private static func latestDeletionsByID(_ deletions: [InstallationSyncDeletion]) -> [UUID: Date] {
        var result = [UUID: Date]()
        result.reserveCapacity(deletions.count)
        for deletion in deletions {
            result[deletion.id] = max(result[deletion.id] ?? .distantPast, deletion.deletedAt)
        }
        return result
    }

    private static func syncRecordSort(_ lhs: InstallationSyncRecord, _ rhs: InstallationSyncRecord) -> Bool {
        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameComparison == .orderedSame {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return nameComparison == .orderedAscending
    }
}

struct AppPreferenceValues: Codable, Equatable {
    var autoRefreshEnabled: Bool
    var autoRefreshInterval: Double
    var driveFailureNotificationsEnabled: Bool
    var desktopNotificationsEnabled: Bool

    static func current(defaults: UserDefaults = .standard) -> Self {
        AppPreferenceValues(
            autoRefreshEnabled: defaults.bool(forKey: AppPreferences.autoRefreshEnabledKey),
            autoRefreshInterval: defaults.object(forKey: AppPreferences.autoRefreshIntervalKey) as? Double
                ?? AppPreferences.defaultAutoRefreshInterval,
            driveFailureNotificationsEnabled: defaults.bool(forKey: AppPreferences.driveFailureNotificationsEnabledKey),
            desktopNotificationsEnabled: defaults.bool(forKey: AppPreferences.desktopNotificationsEnabledKey)
        )
    }

    func apply(to defaults: UserDefaults = .standard) {
        defaults.set(autoRefreshEnabled, forKey: AppPreferences.autoRefreshEnabledKey)
        defaults.set(autoRefreshInterval, forKey: AppPreferences.autoRefreshIntervalKey)
        defaults.set(driveFailureNotificationsEnabled, forKey: AppPreferences.driveFailureNotificationsEnabledKey)
        defaults.set(desktopNotificationsEnabled, forKey: AppPreferences.desktopNotificationsEnabledKey)
    }
}

struct AppPreferencesSyncState: Codable, Equatable {
    var values: AppPreferenceValues
    var updatedAt: Date
}

@MainActor
final class CloudSettingsSynchronizer {
    @MainActor static let shared = CloudSettingsSynchronizer()

    var installationsDidChange: (() -> Void)?

    private let keyValueStore: NSUbiquitousKeyValueStore
    private let defaults: UserDefaults
    private let installationMetadataKey = "ScrutinyMonitor.cloud.installationMetadata.v1"
    private let preferencesUpdatedAtKey = "ScrutinyMonitor.cloud.preferencesUpdatedAt.v1"

    internal var isStarted = false
    private var isApplyingRemotePreferences = false
    internal var lastKnownPreferenceValues: AppPreferenceValues?
    internal var defaultsObserver: NSObjectProtocol?
    internal var backend: SettingsSyncBackend?
    internal var activeProvider: SettingsSyncProvider?
    internal var lastErrorMessage: String?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var isICloudAccountAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    var selectedProvider: SettingsSyncProvider {
        get {
            guard let rawValue = defaults.string(forKey: SettingsSyncDefaults.providerKey),
                  let provider = SettingsSyncProvider(rawValue: rawValue) else {
                return .iCloud
            }

            return provider
        }
        set {
            defaults.set(newValue.rawValue, forKey: SettingsSyncDefaults.providerKey)
            providerConfigurationDidChange()
        }
    }

    var currentStatus: SettingsSyncStatus {
        configureBackendIfNeeded()
        var status = backend?.status ?? SettingsSyncStatus(
            provider: selectedProvider,
            isConfigured: false,
            isAvailable: false,
            message: "Sync is not configured.",
            lastSyncDate: nil
        )

        if let lastErrorMessage {
            status.isAvailable = false
            status.message = lastErrorMessage
        }

        return status
    }

    init(
        keyValueStore: NSUbiquitousKeyValueStore = .default,
        defaults: UserDefaults = .shared
    ) {
        self.keyValueStore = keyValueStore
        self.defaults = defaults
    }

    @discardableResult
    func start() -> Bool {
        configureBackendIfNeeded()

        guard !isStarted else { return true }

        isStarted = true
        lastKnownPreferenceValues = AppPreferenceValues.current(defaults: defaults)

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDefaultsChange()
            }
        }

        Task {
            await reconcilePreferences()
        }

        return true
    }

    func reconcileInstallations(
        _ installations: [ScrutinyInstallation],
        tokenProvider: (UUID) -> Data?
    ) async -> InstallationSyncMergeResult {
        start()

        let now = Date()
        guard let payload = await loadPayload(),
              let envelope = payload.installations else {
            var metadata = loadInstallationMetadata()

            for installation in installations where metadata.recordUpdates[installation.id] == nil {
                metadata.recordUpdates[installation.id] = now
            }

            saveInstallationMetadata(metadata)
            if !installations.isEmpty {
                await publishInstallations(installations, metadata: metadata, existingPayload: nil, now: now)
            }

            return InstallationSyncMergeResult(
                installations: installations,
                metadata: metadata,
                changedInstallations: false,
                deletedTokenIDs: [],
                needsCloudPublish: !installations.isEmpty
            )
        }

        let result = InstallationSyncEngine.merge(
            localInstallations: installations,
            envelope: envelope,
            metadata: loadInstallationMetadata(),
            now: now,
            tokenProvider: tokenProvider
        )

        saveInstallationMetadata(result.metadata)

        if result.needsCloudPublish {
            await publishInstallations(result.installations, metadata: result.metadata, existingPayload: payload, now: now)
        }

        return result
    }

    func noteInstallationChanged(id: UUID, installations: [ScrutinyInstallation]) async {
        start()

        let now = Date()
        var metadata = loadInstallationMetadata()
        metadata.recordUpdates[id] = now
        metadata.deletions.removeValue(forKey: id)

        saveInstallationMetadata(metadata)
        await publishInstallations(installations, metadata: metadata, existingPayload: nil, now: now)
    }

    func noteInstallationDeleted(id: UUID, remainingInstallations: [ScrutinyInstallation]) async {
        start()

        let now = Date()
        var metadata = loadInstallationMetadata()
        metadata.recordUpdates.removeValue(forKey: id)
        metadata.deletions[id] = now

        saveInstallationMetadata(metadata)
        await publishInstallations(remainingInstallations, metadata: metadata, existingPayload: nil, now: now)
    }

    func syncNow() async {
        start()
        await reconcilePreferences()
        installationsDidChange?()
    }

    func providerConfigurationDidChange() {
        reconfigureBackend()
        Task {
            await syncNow()
        }
    }

    func folderPath(for provider: SettingsSyncProvider) -> String? {
        defaults.string(forKey: SettingsSyncDefaults.folderPathKey(for: provider))
    }

    @MainActor func setFolderURL(_ url: URL, for provider: SettingsSyncProvider) throws {
        try saveFolderURL(url, provider: provider, defaults: defaults)
        selectedProvider = provider
    }

    @MainActor func webDAVConfiguration() -> (urlString: String, secureUsernameData: SecureData, hasPassword: Bool) {
        let usernameData = KeychainHelper.shared.readData(
            service: SettingsSyncDefaults.webDAVUsernameService,
            account: SettingsSyncDefaults.webDAVUsernameAccount
        )

        return (
            defaults.string(forKey: SettingsSyncDefaults.webDAVURLKey) ?? "",
            SecureData(data: usernameData ?? Data()),
            KeychainHelper.shared.readData(
                service: SettingsSyncDefaults.webDAVPasswordService,
                account: SettingsSyncDefaults.webDAVPasswordAccount
            ) != nil
        )
    }

    @MainActor func setWebDAVConfiguration(urlString: String, username: String, password: String?) throws {
        let safeURLString = try validateAndFormatWebDAVURL(urlString)
        let credentials = try validateWebDAVCredentials(username: username, password: password)

        saveWebDAVCredentials(username: credentials.username, password: credentials.password)
        defaults.set(safeURLString, forKey: SettingsSyncDefaults.webDAVURLKey)
        selectedProvider = .webDAV

        // Recreate the backend to clear in-memory caches and pick up new credentials
        reconfigureBackend()
    }

    private func validateAndFormatWebDAVURL(_ urlString: String) throws -> String {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURLString), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SettingsSyncError.invalidWebDAVURL
        }

        if components.user != nil || components.password != nil {
            throw SettingsSyncError.inlineCredentialsNotSupported
        }

        if let queryItems = components.queryItems {
            let forbidden = ["user", "password", "pass", "username", "token", "key", "secret", "apikey"]
            if queryItems.contains(where: { forbidden.contains($0.name.lowercased()) }) {
                throw SettingsSyncError.inlineCredentialsNotSupported
            }
        }

        guard let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw SettingsSyncError.invalidWebDAVURL
        }

        guard let host = components.host, !host.isEmpty else {
            throw SettingsSyncError.invalidWebDAVURL
        }

        if scheme == "http" {
            guard NetworkSecurity.isLocalHost(host) else {
                throw SettingsSyncError.insecureWebDAVURL
            }
        }

        guard let safeURL = components.url else {
            throw SettingsSyncError.invalidWebDAVURL
        }
        return safeURL.absoluteString
    }

    private func validateWebDAVCredentials(username: String, password: String?) throws -> (username: String, password: String?) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUsername.isEmpty, let password, !password.isEmpty {
            throw SettingsSyncError.passwordWithoutUsername
        }

        return (trimmedUsername, password)
    }

    private func saveWebDAVCredentials(username trimmedUsername: String, password: String?) {
        if trimmedUsername.isEmpty {
            KeychainHelper.shared.delete(
                service: SettingsSyncDefaults.webDAVUsernameService,
                account: SettingsSyncDefaults.webDAVUsernameAccount
            )
            KeychainHelper.shared.delete(
                service: SettingsSyncDefaults.webDAVPasswordService,
                account: SettingsSyncDefaults.webDAVPasswordAccount
            )
        } else {
            KeychainHelper.shared.saveData(
                trimmedUsername.data(using: .utf8) ?? Data(),
                service: SettingsSyncDefaults.webDAVUsernameService,
                account: SettingsSyncDefaults.webDAVUsernameAccount
            )

            if let password {
                if password.isEmpty {
                    KeychainHelper.shared.delete(
                        service: SettingsSyncDefaults.webDAVPasswordService,
                        account: SettingsSyncDefaults.webDAVPasswordAccount
                    )
                } else {
                    KeychainHelper.shared.saveData(
                        password.data(using: .utf8) ?? Data(),
                        service: SettingsSyncDefaults.webDAVPasswordService,
                        account: SettingsSyncDefaults.webDAVPasswordAccount
                    )
                }
            }
        }
    }

    @MainActor private func handleDefaultsChange() {
        guard !isApplyingRemotePreferences else { return }

        let currentValues = AppPreferenceValues.current(defaults: defaults)
        guard currentValues != lastKnownPreferenceValues else { return }

        Task {
            await publishPreferences(values: currentValues, updatedAt: Date(), existingPayload: nil)
        }
    }

    private func reconcilePreferences() async {
        let payload = await loadPayload()

        guard let remoteState = payload?.preferences else {
            await publishPreferences(
                values: AppPreferenceValues.current(defaults: defaults),
                updatedAt: Date(),
                existingPayload: payload
            )
            return
        }

        let localUpdatedAt = defaults.object(forKey: preferencesUpdatedAtKey) as? Date ?? .distantPast

        if remoteState.updatedAt > localUpdatedAt {
            applyPreferences(remoteState)
        } else {
            let currentValues = AppPreferenceValues.current(defaults: defaults)
            if localUpdatedAt > remoteState.updatedAt || currentValues != remoteState.values {
                await publishPreferences(
                    values: currentValues,
                    updatedAt: max(localUpdatedAt, Date()),
                    existingPayload: payload
                )
            }
        }
    }

    private func applyPreferences(_ state: AppPreferencesSyncState) {
        isApplyingRemotePreferences = true
        defer { isApplyingRemotePreferences = false }

        state.values.apply(to: defaults)
        defaults.set(state.updatedAt, forKey: preferencesUpdatedAtKey)
        lastKnownPreferenceValues = state.values
    }

    private func publishPreferences(
        values: AppPreferenceValues,
        updatedAt: Date,
        existingPayload: SettingsSyncPayload?
    ) async {
        let state = AppPreferencesSyncState(values: values, updatedAt: updatedAt)
        await savePayload(existingPayload: existingPayload) { payload in
            payload.preferences = state
        }

        defaults.set(updatedAt, forKey: preferencesUpdatedAtKey)
        lastKnownPreferenceValues = values
    }

    private func publishInstallations(
        _ installations: [ScrutinyInstallation],
        metadata: InstallationSyncMetadata,
        existingPayload: SettingsSyncPayload?,
        now: Date
    ) async {
        var publishMetadata = metadata

        for installation in installations where publishMetadata.recordUpdates[installation.id] == nil {
            publishMetadata.recordUpdates[installation.id] = now
        }

        if publishMetadata != metadata {
            saveInstallationMetadata(publishMetadata)
        }

        await savePayload(existingPayload: existingPayload) { payload in
            payload.installations = InstallationSyncEngine.publishingEnvelope(
                installations: installations,
                metadata: publishMetadata,
                existingEnvelope: payload.installations,
                now: now
            )
        }
    }

    internal func loadPayload() async -> SettingsSyncPayload? {
        configureBackendIfNeeded()

        do {
            let payload = try await backend?.loadPayload()
            markSyncSucceeded()
            return payload
        } catch {
            lastErrorMessage = error.secureDescription
            return nil
        }
    }

    private func savePayload(
        existingPayload: SettingsSyncPayload?,
        update: (inout SettingsSyncPayload) -> Void
    ) async {
        configureBackendIfNeeded()

        do {
            var payload: SettingsSyncPayload
            if let existingPayload {
                payload = existingPayload
            } else if let loadedPayload = try await backend?.loadPayload() {
                payload = loadedPayload
            } else {
                payload = SettingsSyncPayload()
            }

            update(&payload)
            try await backend?.savePayload(payload)
            markSyncSucceeded()
        } catch {
            lastErrorMessage = error.secureDescription
        }
    }

    private func loadInstallationMetadata() -> InstallationSyncMetadata {
        decode(InstallationSyncMetadata.self, from: defaults.data(forKey: installationMetadataKey))
            ?? InstallationSyncMetadata()
    }

    private func saveInstallationMetadata(_ metadata: InstallationSyncMetadata) {
        guard let data = encode(metadata) else { return }
        defaults.set(data, forKey: installationMetadataKey)
    }

    private func configureBackendIfNeeded() {
        if activeProvider != selectedProvider || backend == nil {
            reconfigureBackend()
        }
    }

    private func reconfigureBackend() {
        backend?.stopObserving()

        let provider = selectedProvider
        activeProvider = provider
        backend = makeBackend(for: provider)
        backend?.startObserving { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleExternalChange()
            }
        }
    }

    private func makeBackend(for provider: SettingsSyncProvider) -> SettingsSyncBackend {
        switch provider {
        case .iCloud:
            ICloudSettingsSyncBackend(keyValueStore: keyValueStore, defaults: defaults)
        case .selectFolder:
            FolderSettingsSyncBackend(provider: provider, defaults: defaults)
        case .webDAV:
            WebDAVSettingsSyncBackend(defaults: defaults)
        }
    }

    private func handleExternalChange() async {
        await reconcilePreferences()
        installationsDidChange?()
    }

    private func markSyncSucceeded() {
        let now = Date()
        lastErrorMessage = nil
        defaults.set(now, forKey: SettingsSyncDefaults.lastSyncDateKey)
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? encoder.encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
