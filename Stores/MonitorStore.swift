import Foundation
import Observation
import Network

@MainActor
@Observable
final class MonitorStore {
    var installations: [ScrutinyInstallation] = [] {
        didSet {
            guard !isLoading else { return }
            updateAggregates()
            scheduleSave()
        }
    }
    var selection: MonitorSelection?
    var overviewDriveCount: Int = 0
    var overviewHasIssues: Bool = false
    var isRefreshing: Bool = false
    var overallStatus: InstallationStatus = .empty
    var lastRefreshDate: Date? = nil

    @ObservationIgnored private let client: ScrutinyClient
    @ObservationIgnored private let persistence: InstallationPersistence
    @ObservationIgnored private let cloudSync: CloudSettingsSynchronizer
    @ObservationIgnored private let notificationService: DriveFailureNotificationService
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(
        client: ScrutinyClient,
        persistence: InstallationPersistence,
        cloudSync: CloudSettingsSynchronizer,
        notificationService: DriveFailureNotificationService
    ) {
        self.client = client
        self.persistence = persistence
        self.cloudSync = cloudSync
        self.notificationService = notificationService

        isLoading = true
        var loaded = persistence.load()

        // ⚡ Bolt: Use O(1) bulk fetch to avoid sequential IPC overhead with security daemon on startup
        let tokens = KeychainHelper.shared.readAllData(service: InstallationPersistence.installationsKey)
        // ⚡ Bolt: Index-based mutation is required to modify array elements in place
        // without creating unnecessary copies of `ScrutinyInstallation` structs.
        for i in 0..<loaded.count {
            if let tokenData = tokens[loaded[i].id.uuidString] {
                loaded[i].apiToken = tokenData
            }
        }

        installations = loaded
        selection = installations.count > 1 ? .overview : installations.first.map { .installation($0.id) }
        isLoading = false

        cloudSync.installationsDidChange = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.applyCloudInstallationChanges()
            }
        }
        cloudSync.start()
        Task {
            await applyCloudInstallationChanges()
        }
        updateAggregates()
    }

    private func updateAggregates() {
        var drives = 0
        var refreshing = false

        var hasCritical = false
        var hasWarning = false
        var hasOffline = false
        var maxRefreshDate: Date? = nil

        for installation in installations {
            if let date = installation.lastRefreshDate {
                maxRefreshDate = max(maxRefreshDate ?? date, date)
            }
            drives += installation.lastSnapshot?.totalDrives ?? 0

            switch installation.status {
            case .critical: hasCritical = true
            case .warning: hasWarning = true
            case .offline: hasOffline = true
            case .healthy, .refreshing, .empty, .unknown: break
            }
            if installation.isRefreshing {
                refreshing = true
            }
        }

        overviewDriveCount = drives
        let hasIssues = hasCritical || hasWarning || hasOffline
        overviewHasIssues = hasIssues
        isRefreshing = refreshing
        lastRefreshDate = maxRefreshDate
        overallStatus = determineOverallStatus(
            isEmpty: installations.isEmpty,
            hasCritical: hasCritical,
            hasWarning: hasWarning,
            hasOffline: hasOffline,
            isRefreshing: refreshing
        )
    }

    private func determineOverallStatus(
        isEmpty: Bool,
        hasCritical: Bool,
        hasWarning: Bool,
        hasOffline: Bool,
        isRefreshing: Bool
    ) -> InstallationStatus {
        if isEmpty { return .empty }
        if hasCritical { return .critical }
        if hasWarning { return .warning }
        if hasOffline { return .offline }
        if isRefreshing { return .refreshing }
        return .healthy
    }

    @MainActor
    convenience init() {
        self.init(
            client: .shared,
            persistence: InstallationPersistence(),
            cloudSync: .shared,
            notificationService: .shared
        )
    }

    var selectedInstallation: ScrutinyInstallation? {
        guard case .installation(let id) = selection else { return nil }
        return installations.first { $0.id == id }
    }

    @MainActor func addInstallation(name: String, baseURLString: String, apiToken: String) throws {
        try Self.validateInputs(name: name, baseURLString: baseURLString, apiToken: apiToken)

        let baseURL = try Self.normalizedURL(from: baseURLString)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenData = token.data(using: .utf8) ?? Data()

        let installation = ScrutinyInstallation(
            name: trimmedName.isEmpty ? baseURL.host(percentEncoded: false) ?? baseURL.absoluteString : trimmedName,
            baseURL: baseURL,
            apiToken: tokenData
        )

        if !tokenData.isEmpty {
            KeychainHelper.shared.saveData(tokenData, service: InstallationPersistence.installationsKey, account: installation.id.uuidString, accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        }

        installations.append(installation)
        selection = .installation(installation.id)
        let currentInstallations = installations
        Task {
            await cloudSync.noteInstallationChanged(id: installation.id, installations: currentInstallations)
        }
    }

    @MainActor func updateInstallation(id: UUID, name: String, baseURLString: String, apiToken: String) throws {
        try Self.validateInputs(name: name, baseURLString: baseURLString, apiToken: apiToken)

        guard let index = installations.firstIndex(where: { $0.id == id }) else { return }

        let baseURL = try Self.normalizedURL(from: baseURLString)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenData = token.data(using: .utf8) ?? Data()

        installations[index].name = trimmedName.isEmpty ? baseURL.host(percentEncoded: false) ?? baseURL.absoluteString : trimmedName
        installations[index].baseURL = baseURL
        installations[index].apiToken = tokenData
        installations[index].lastError = nil

        if tokenData.isEmpty {
            KeychainHelper.shared.delete(service: InstallationPersistence.installationsKey, account: id.uuidString)
        } else {
            KeychainHelper.shared.saveData(tokenData, service: InstallationPersistence.installationsKey, account: id.uuidString, accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        }

        let currentInstallations = installations
        Task {
            await cloudSync.noteInstallationChanged(id: id, installations: currentInstallations)
        }
    }

    @discardableResult
    func removeSelectedInstallation() -> Task<Void, Never>? {
        guard case .installation(let id) = selection else { return nil }
        KeychainHelper.shared.delete(service: InstallationPersistence.installationsKey, account: id.uuidString)
        installations.removeAll { $0.id == id }
        self.selection = installations.count > 1 ? .overview : installations.first.map { .installation($0.id) }
        let remainingInstallations = installations
        return Task {
            await cloudSync.noteInstallationDeleted(id: id, remainingInstallations: remainingInstallations)
        }
    }

    func refreshSelected() async {
        guard case .installation(let id) = selection else { return }
        await refresh(id: id)
    }

    func refreshAll() async {
        let batchedInstallations = prepareInstallationsForRefresh()
        await executeBatchRefresh(for: batchedInstallations)
    }

    private func prepareInstallationsForRefresh() -> [ScrutinyInstallation] {
        // ⚡ Bolt: Batch update installations to avoid O(N^2) firstIndex lookups
        // and redundant @Observable state updates triggering excessive saves.
        let batchedInstallations = installations.map { installation in
            var updated = installation
            updated.isRefreshing = true
            updated.lastError = nil
            return updated
        }
        installations = batchedInstallations
        return batchedInstallations
    }

    private func executeBatchRefresh(for batchedInstallations: [ScrutinyInstallation]) async {
        guard !batchedInstallations.isEmpty else { return }
        await withTaskGroup(of: (UUID, Int, Result<InstallationSnapshot, Error>).self) { group in
            for (index, installation) in batchedInstallations.enumerated() {
                group.addTask {
                    if Task.isCancelled {
                        return (installation.id, index, .failure(CancellationError()))
                    }
                    do {
                        let snapshot = try await self.client.fetchSnapshot(for: installation)
                        return (installation.id, index, .success(snapshot))
                    } catch {
                        return (installation.id, index, .failure(error))
                    }
                }
            }

            for await result in group {
                applyRefreshResult(id: result.0, indexHint: result.1, result: result.2)
            }
        }
    }

    private func refresh(id: UUID) async {
        guard let index = installations.firstIndex(where: { $0.id == id }) else { return }
        let installation = installations[index]
        markRefreshing(id: id, indexHint: index, isRefreshing: true)

        do {
            let snapshot = try await client.fetchSnapshot(for: installation)
            applyRefreshResult(id: id, indexHint: index, result: .success(snapshot))
        } catch {
            applyRefreshResult(id: id, indexHint: index, result: .failure(error))
        }
    }

    private func markRefreshing(id: UUID, indexHint: Int? = nil, isRefreshing: Bool) {
        let index: Int
        if let hint = indexHint, hint >= 0, hint < installations.count, installations[hint].id == id {
            index = hint
        } else if let foundIndex = installations.firstIndex(where: { $0.id == id }) {
            index = foundIndex
        } else {
            return
        }

        installations[index].isRefreshing = isRefreshing
        if isRefreshing {
            installations[index].lastError = nil
        }
    }

    private func applyRefreshResult(id: UUID, indexHint: Int? = nil, result: Result<InstallationSnapshot, Error>) {
        let index: Int
        if let hint = indexHint, hint >= 0, hint < installations.count, installations[hint].id == id {
            index = hint
        } else if let foundIndex = installations.firstIndex(where: { $0.id == id }) {
            index = foundIndex
        } else {
            return
        }

        installations[index].isRefreshing = false
        installations[index].lastRefreshDate = Date()

        switch result {
        case .success(let snapshot):
            let alerts = DriveFailureAlert.newlyAtRiskDrives(
                installationName: installations[index].name,
                previous: installations[index].lastSnapshot,
                current: snapshot
            )
            installations[index].lastSnapshot = snapshot
            installations[index].lastError = nil
            notificationService.deliver(alerts)
        case .failure(let error):
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                installations[index].lastError = nil
            } else {
                installations[index].lastError = error.secureDescription
            }
        }
    }

    private func applyCloudInstallationChanges() async {
        let tokens = KeychainHelper.shared.readAllData(service: InstallationPersistence.installationsKey)
        let result = await cloudSync.reconcileInstallations(installations) { id in
            tokens[id.uuidString]
        }

        persistence.deleteTokens(for: result.deletedTokenIDs)

        guard result.changedInstallations else { return }

        installations = result.installations
        repairSelection()
    }

    private func tokenData(for id: UUID) -> Data? {
        KeychainHelper.shared.readData(
            service: InstallationPersistence.installationsKey,
            account: id.uuidString
        )
    }

    private func repairSelection() {
        if case .installation(let id) = selection,
           installations.contains(where: { $0.id == id }) {
            return
        }

        selection = installations.count > 1 ? .overview : installations.first.map { .installation($0.id) }
    }

    private func scheduleSave() {
        saveTask?.cancel()

        // Capture the current installations to avoid accessing the MainActor property from the background task
        let currentInstallations = installations
        let persistence = self.persistence

        saveTask = Task.detached {
            do {
                // Debounce for 500ms
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return // Task was cancelled, so don't save
            }

            // Task wasn't cancelled, execute save
            // ⚡ Bolt: Using Task.detached prevents inheriting the @MainActor context.
            // This ensures the synchronous JSON encoding and disk I/O in persistence.save()
            // actually runs on a background thread instead of blocking the main thread.
            persistence.save(currentInstallations)
        }
    }

    private static func validateInputs(name: String, baseURLString: String, apiToken: String) throws {
        let trimmedBaseURLString = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.count > 100 {
            throw InstallationValidationError.invalidInput("Name must be 100 characters or less.")
        }

        if name.rangeOfCharacter(from: .controlCharacters) != nil {
            throw InstallationValidationError.invalidInput("Name contains invalid characters.")
        }

        if trimmedBaseURLString.count > 1024 {
            throw InstallationValidationError.invalidInput("URL must be 1024 characters or less.")
        }

        if trimmedBaseURLString.rangeOfCharacter(from: .controlCharacters) != nil {
            throw InstallationValidationError.invalidInput("URL contains invalid characters.")
        }

        if trimmedAPIToken.count > 4096 {
            throw InstallationValidationError.invalidInput("API token must be 4096 characters or less.")
        }

        if trimmedAPIToken.rangeOfCharacter(from: .controlCharacters) != nil {
            throw InstallationValidationError.invalidInput("API token contains invalid characters.")
        }
    }

    private static func normalizedURL(from string: String) throws -> URL {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw InstallationValidationError.emptyURL
        }

        var components = URLComponents(string: trimmed.contains("://") ? trimmed : "//\(trimmed)")
        if !trimmed.contains("://") {
            components?.scheme = "http"
        }

        components?.user = nil
        components?.password = nil

        guard let url = components?.url, let scheme = url.scheme, let host = url.host(), !host.isEmpty else {
            throw InstallationValidationError.invalidURL
        }

        guard ["http", "https"].contains(scheme.lowercased()) else {
            throw InstallationValidationError.unsupportedScheme
        }

        if scheme.lowercased() == "http" && !NetworkSecurity.isLocalHost(host) {
            throw InstallationValidationError.insecureURL
        }

        return url
    }
}
