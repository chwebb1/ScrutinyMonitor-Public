import Foundation
import os

struct SettingsSyncPayload: Codable, Equatable {
    static let currentVersion = 1

    var version = Self.currentVersion
    var installations: InstallationSyncEnvelope?
    var preferences: AppPreferencesSyncState?
}

struct SettingsSyncStatus: Equatable {
    var provider: SettingsSyncProvider
    var isConfigured: Bool
    var isAvailable: Bool
    var message: String
    var lastSyncDate: Date?
}

protocol SettingsSyncBackend: AnyObject {
    var provider: SettingsSyncProvider { get }
    var status: SettingsSyncStatus { get }

    func startObserving(_ onExternalChange: @escaping @Sendable @MainActor () -> Void)
    func stopObserving()
    func loadPayload() async throws -> SettingsSyncPayload?
    func savePayload(_ payload: SettingsSyncPayload) async throws
}

enum SettingsSyncDefaults {
    static let providerKey = "ScrutinyMonitor.sync.provider"
    static let lastSyncDateKey = "ScrutinyMonitor.sync.lastSyncDate"
    static let webDAVURLKey = "ScrutinyMonitor.sync.webdav.url"
    static let webDAVUsernameService = "ScrutinyMonitor.sync.webdav"
    static let webDAVUsernameAccount = "username"
    static let webDAVPasswordService = "ScrutinyMonitor.sync.webdav"
    static let webDAVPasswordAccount = "password"
    static let syncFileName = "ScrutinyMonitor.settings.json"

    static func folderBookmarkKey(for provider: SettingsSyncProvider) -> String {
        "ScrutinyMonitor.sync.\(provider.rawValue).folderBookmark"
    }

    static func folderPathKey(for provider: SettingsSyncProvider) -> String {
        "ScrutinyMonitor.sync.\(provider.rawValue).folderPath"
    }
}

final class ICloudSettingsSyncBackend: SettingsSyncBackend {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScrutinyMonitor", category: "ICloudSettingsSyncBackend")

    let provider: SettingsSyncProvider = .iCloud

    private let keyValueStore: NSUbiquitousKeyValueStore
    private let defaults: UserDefaults
    private let installationsKey = "ScrutinyMonitor.cloud.installations.v1"
    private let preferencesKey = "ScrutinyMonitor.cloud.preferences.v1"
    private var cloudObserver: NSObjectProtocol?

    init(keyValueStore: NSUbiquitousKeyValueStore = .default, defaults: UserDefaults = .standard) {
        self.keyValueStore = keyValueStore
        self.defaults = defaults
    }

    var status: SettingsSyncStatus {
        SettingsSyncStatus(
            provider: provider,
            isConfigured: true,
            isAvailable: FileManager.default.ubiquityIdentityToken != nil,
            message: FileManager.default.ubiquityIdentityToken != nil ? "Sync available" : "Sign in to iCloud to sync",
            lastSyncDate: defaults.object(forKey: SettingsSyncDefaults.lastSyncDateKey) as? Date
        )
    }

    func startObserving(_ onExternalChange: @escaping @Sendable @MainActor () -> Void) {
        stopObserving()
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: keyValueStore,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            if changedKeys == nil ||
                changedKeys?.contains(self.installationsKey) == true ||
                changedKeys?.contains(self.preferencesKey) == true {
                Task { @MainActor in
                    onExternalChange()
                }
            }
        }
    }

    func stopObserving() {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
            self.cloudObserver = nil
        }
    }

    func loadPayload() async throws -> SettingsSyncPayload? {
        keyValueStore.synchronize()

        let installations = try decodeInstallations(from: keyValueStore.data(forKey: installationsKey))
        let preferences = try decodePreferences(from: keyValueStore.data(forKey: preferencesKey))

        guard installations != nil || preferences != nil else {
            return nil
        }

        return SettingsSyncPayload(installations: installations, preferences: preferences)
    }

    private func decodeInstallations(from data: Data?) throws -> InstallationSyncEnvelope? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(InstallationSyncEnvelope.self, from: data)
        } catch {
            Self.logger.error("Failed to decode installations: \(error, privacy: .private)")
            throw error
        }
    }

    private func decodePreferences(from data: Data?) throws -> AppPreferencesSyncState? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(AppPreferencesSyncState.self, from: data)
        } catch {
            Self.logger.error("Failed to decode preferences: \(error, privacy: .private)")
            throw error
        }
    }

    func savePayload(_ payload: SettingsSyncPayload) async throws {
        let encoder = JSONEncoder()
        if let installations = payload.installations {
            let data = try encoder.encode(installations)
            keyValueStore.set(data, forKey: installationsKey)
        } else {
            keyValueStore.removeObject(forKey: installationsKey)
        }

        if let preferences = payload.preferences {
            let data = try encoder.encode(preferences)
            keyValueStore.set(data, forKey: preferencesKey)
        } else {
            keyValueStore.removeObject(forKey: preferencesKey)
        }

        keyValueStore.synchronize()
    }
}

// @unchecked Sendable: Thread safety is ensured by protecting mutable state with `stateLock`
// and using @MainActor for observation callbacks. NSFilePresenter callbacks are
// inherently cross-threaded but observation state is properly synchronized.
// The lifecycleLock serializes startObserving/stopObserving transitions.
final class FolderSettingsSyncBackend: NSObject, SettingsSyncBackend, NSFilePresenter, @unchecked Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScrutinyMonitor", category: "FolderSettingsSyncBackend")

    private let stateLock = NSLock()
    private let lifecycleLock = NSLock()

    let provider: SettingsSyncProvider

    private let defaults: UserDefaults
    private let fileManager: FileManager

    private var _presentedItemURL: URL?
    var presentedItemURL: URL? {
        stateLock.withLock { _presentedItemURL }
    }
    let presentedItemOperationQueue: OperationQueue

    private var onExternalChange: (@Sendable @MainActor () -> Void)?
    private var securityScopedURL: URL?
    init(
        provider: SettingsSyncProvider,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        self.presentedItemOperationQueue = queue
        self.provider = provider
        self.defaults = defaults
        self.fileManager = fileManager
        super.init()
    }

    deinit {
        stopObserving()
    }

    var status: SettingsSyncStatus {
        let path = defaults.string(forKey: SettingsSyncDefaults.folderPathKey(for: provider))
        let isConfigured = path?.isEmpty == false

        return SettingsSyncStatus(
            provider: provider,
            isConfigured: isConfigured,
            isAvailable: isConfigured,
            message: isConfigured ? path ?? "Folder selected" : "Choose a sync folder",
            lastSyncDate: defaults.object(forKey: SettingsSyncDefaults.lastSyncDateKey) as? Date
        )
    }

    func startObserving(_ onExternalChange: @escaping @Sendable @MainActor () -> Void) {
        lifecycleLock.withLock {
            let urlToRemove = stateLock.withLock { _presentedItemURL }
            if urlToRemove != nil {
                NSFileCoordinator.removeFilePresenter(self)
            }
            clearObservationState()

            let folderURL: URL
            do {
                folderURL = try resolveFolderURL()
            } catch {
                Self.logger.error("Failed to resolve folder URL for observing: \(error.localizedDescription, privacy: .private)")
                return
            }

            let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
            let didAccessSecurityScopedResource = folderURL.startAccessingSecurityScopedResource()

            stateLock.withLock {
                if didAccessSecurityScopedResource {
                    securityScopedURL = folderURL
                }
                _presentedItemURL = fileURL
                self.onExternalChange = onExternalChange
            }
            if !didAccessSecurityScopedResource {
                Self.logger.warning("Failed to access security scoped resource for folder: \(folderURL.path, privacy: .private)")
            }
            NSFileCoordinator.addFilePresenter(self)
        }
    }

    func stopObserving() {
        lifecycleLock.withLock {
            let urlToRemove = stateLock.withLock { _presentedItemURL }
            if urlToRemove != nil {
                NSFileCoordinator.removeFilePresenter(self)
            }
            clearObservationState()
        }
    }

    /// Clears observation state atomically - must be called while holding lifecycleLock
    private func clearObservationState() {
        let urlToRelease = stateLock.withLock {
            let url = securityScopedURL
            _presentedItemURL = nil
            securityScopedURL = nil
            onExternalChange = nil
            return url
        }
        urlToRelease?.stopAccessingSecurityScopedResource()
    }

    func presentedItemDidChange() {
        // Copy the handler while holding the lock, then release the lock before invoking
        // The handler is @MainActor so it will be invoked on the main thread regardless
        let handler = stateLock.withLock { onExternalChange }
        if let handler {
            Task { @MainActor in handler() }
        }
    }

    private func decodePayload(from url: URL) throws -> SettingsSyncPayload? {
        var resultData: Data?
        var coordinatorError: NSError?
        var thrownError: Error?

        let coordinator = NSFileCoordinator(filePresenter: self)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                resultData = try Data(contentsOf: coordinatedURL)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                // file doesn't exist yet, return nil
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOENT) {
                    // file doesn't exist yet
                } else {
                    thrownError = error
                }
            }
        }

        if let error = thrownError ?? coordinatorError {
            throw error
        }

        guard let data = resultData, !data.isEmpty else { return nil }
        return try JSONDecoder().decode(SettingsSyncPayload.self, from: data)
    }

    func loadPayload() async throws -> SettingsSyncPayload? {
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                throw SettingsSyncError.backendDeallocated
            }
            try Task.checkCancellation()
            return try self.withSyncFileURL { fileURL in
                try self.decodePayload(from: fileURL)
            }
        }.value
    }

    private func encodeAndWritePayload(_ payload: SettingsSyncPayload, to url: URL) throws {
        let data = try JSONEncoder().encode(payload)

        var coordinatorError: NSError?
        var thrownError: Error?

        let coordinator = NSFileCoordinator(filePresenter: self)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordinatedURL in
            do {
                #if os(iOS)
                try data.write(to: coordinatedURL, options: [.atomic, .completeFileProtection])
                #else
                try data.write(to: coordinatedURL, options: [.atomic])
                #endif
            } catch {
                thrownError = error
            }
        }

        if let error = thrownError ?? coordinatorError {
            throw error
        }
    }

    func savePayload(_ payload: SettingsSyncPayload) async throws {
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                throw SettingsSyncError.backendDeallocated
            }
            try Task.checkCancellation()
            try self.withSyncFileURL { fileURL in
                try self.encodeAndWritePayload(payload, to: fileURL)
            }
        }.value
    }

    private func withSyncFileURL<T>(_ action: (URL) throws -> T) throws -> T {
        let folderURL = try resolveFolderURL()
        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        return try action(fileURL)
    }

    private func resolveFolderURL() throws -> URL {
        if let bookmarkData = defaults.data(forKey: SettingsSyncDefaults.folderBookmarkKey(for: provider)) {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try saveFolderURL(url, provider: provider, defaults: defaults)
            }

            return url
        }

        if let path = defaults.string(forKey: SettingsSyncDefaults.folderPathKey(for: provider)), !path.isEmpty {
            return URL(fileURLWithPath: path)
        }

        throw SettingsSyncError.providerNotConfigured(provider)
    }
}


final class WebDAVSettingsSyncBackend: SettingsSyncBackend, @unchecked Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScrutinyMonitor", category: "WebDAVSettingsSyncBackend")

    let provider: SettingsSyncProvider = .webDAV

    private let defaults: UserDefaults
    private let session: URLSession

    private var cachedPasswordData: SecureData?
    private var hasFetchedPassword = false
    private var cachedUsernameData: SecureData?
    private var hasFetchedUsername = false
    private let stateLock = NSLock()

    private var secureUsernameData: SecureData {
        stateLock.lock()
        defer { stateLock.unlock() }

        if hasFetchedUsername {
            return cachedUsernameData ?? SecureData(data: Data())
        }

        let usernameData = KeychainHelper.shared.readData(
            service: SettingsSyncDefaults.webDAVUsernameService,
            account: SettingsSyncDefaults.webDAVUsernameAccount
        )
        let secureData = SecureData(data: usernameData ?? Data())

        cachedUsernameData = secureData
        hasFetchedUsername = true
        return secureData
    }

    init(defaults: UserDefaults = .standard, session: URLSession? = nil) {
        self.defaults = defaults
        // 🛡️ Sentinel: Use ephemeral configuration to avoid caching sync data/passwords to disk
        self.session = session ?? URLSession(configuration: .ephemeral)
    }

    deinit {
        pollTask?.cancel()
    }

    private func getPasswordData() -> SecureData {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        if !hasFetchedPassword {
            if let fetched = KeychainHelper.shared.readData(
                service: SettingsSyncDefaults.webDAVPasswordService,
                account: SettingsSyncDefaults.webDAVPasswordAccount
            ) {
                cachedPasswordData = SecureData(data: fetched)
            } else {
                cachedPasswordData = SecureData(data: Data())
            }
            hasFetchedPassword = true
        }
        return cachedPasswordData ?? SecureData(data: Data())
    }

    var status: SettingsSyncStatus {
        let isConfigured = webDAVFolderURL != nil
        return SettingsSyncStatus(
            provider: provider,
            isConfigured: isConfigured,
            isAvailable: isConfigured,
            message: isConfigured ? webDAVFolderURL?.absoluteString ?? "WebDAV configured" : "Enter a WebDAV folder URL",
            lastSyncDate: defaults.object(forKey: SettingsSyncDefaults.lastSyncDateKey) as? Date
        )
    }

    private var pollTask: Task<Void, Never>?

    func startObserving(_ onExternalChange: @escaping @Sendable @MainActor () -> Void) {
        stateLock.lock()
        pollTask?.cancel()
        _invalidateCache()
        
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    return
                }
                guard self != nil else { return }
                if !Task.isCancelled {
                    await MainActor.run {
                        if !Task.isCancelled {
                            onExternalChange()
                        }
                    }
                }
            }
        }
        stateLock.unlock()
    }

    private func _invalidateCache() {
        cachedPasswordData = nil
        hasFetchedPassword = false
        cachedUsernameData = nil
        hasFetchedUsername = false
    }

    private func invalidateCache() {
        stateLock.lock()
        defer { stateLock.unlock() }
        _invalidateCache()
    }

    func stopObserving() {
        stateLock.lock()
        pollTask?.cancel()
        pollTask = nil
        _invalidateCache()
        stateLock.unlock()
    }

    /// Executes a request and validates the HTTP response
    /// - Parameter request: The URLRequest to execute
    /// - Parameter allowsMissingPayload: If true, returns nil for 404 instead of throwing
    /// - Returns: The data and HTTP response
    private func execute(request: URLRequest, allowsMissingPayload: Bool = false) async throws -> (data: Data, response: HTTPURLResponse) {
        let (data, response) = try await session.data(
            for: request,
            delegate: makeDelegate(for: request)
        )
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SettingsSyncError.missingHTTPResponse
        }

        if httpResponse.statusCode == 401 {
            invalidateCache()
        }

        if allowsMissingPayload && httpResponse.statusCode == 404 {
            return (data, httpResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SettingsSyncError.serverRejectedRequest(httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    func loadPayload() async throws -> SettingsSyncPayload? {
        var request = try request(method: "GET")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, httpResponse) = try await execute(request: request, allowsMissingPayload: true)

        if httpResponse.statusCode == 404 {
            return nil
        }

        return try JSONDecoder().decode(SettingsSyncPayload.self, from: data)
    }

    func savePayload(_ payload: SettingsSyncPayload) async throws {
        var request = try request(method: "PUT")
        request.httpBody = try JSONEncoder().encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        _ = try await execute(request: request)
    }

    private func makeDelegate(for request: URLRequest) -> WebDAVAuthDelegate? {
        guard let host = request.url?.host(), let scheme = request.url?.scheme else { return nil }
        return WebDAVAuthDelegate(
            expectedHost: host,
            expectedScheme: scheme,
            secureUsernameData: secureUsernameData,
            securePasswordData: getPasswordData()
        )
    }

    private var webDAVFolderURL: URL? {
        guard let string = defaults.string(forKey: SettingsSyncDefaults.webDAVURLKey), !string.isEmpty else {
            return nil
        }

        return URL(string: string)
    }

    private func request(method: String) throws -> URLRequest {
        guard let folderURL = webDAVFolderURL else {
            throw SettingsSyncError.providerNotConfigured(.webDAV)
        }

        let fileURL = folderURL.appendingPathComponent(SettingsSyncDefaults.syncFileName)
        guard let scheme = fileURL.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw SettingsSyncError.invalidWebDAVURL
        }

        if scheme == "http" {
            guard let host = fileURL.host(), NetworkSecurity.isLocalHost(host) else {
                throw SettingsSyncError.insecureWebDAVURL
            }
        }

        var request = URLRequest(url: fileURL)
        request.httpMethod = method
        request.timeoutInterval = 15

        return request
    }
}

final class WebDAVAuthDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let expectedHost: String
    let expectedScheme: String
    private let secureUsernameData: SecureData
    private let securePasswordData: SecureData

    init(expectedHost: String, expectedScheme: String, secureUsernameData: SecureData, securePasswordData: SecureData) {
        self.expectedHost = expectedHost
        self.expectedScheme = expectedScheme
        self.secureUsernameData = secureUsernameData
        self.securePasswordData = securePasswordData
        super.init()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.host.caseInsensitiveCompare(expectedHost) == .orderedSame else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let authMethod = challenge.protectionSpace.authenticationMethod
        guard authMethod == NSURLAuthenticationMethodHTTPBasic || authMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard challenge.previousFailureCount == 0 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let proto = challenge.protectionSpace.protocol, proto.caseInsensitiveCompare(expectedScheme) == .orderedSame else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if proto.caseInsensitiveCompare(NSURLProtectionSpaceHTTPS) != .orderedSame,
           !NetworkSecurity.isLocalHost(challenge.protectionSpace.host) {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Security Limitation: URLCredential inherently requires a String. This means the
        // cleartext password will temporarily exist as a String on the heap and cannot be
        // deterministically zeroized. This is a known Foundation API limitation.
        let username = secureUsernameData.withUnsafeBytes { buffer in
            String(bytes: buffer, encoding: .utf8) ?? ""
        }
        let password = securePasswordData.withUnsafeBytes { buffer in
            String(bytes: buffer, encoding: .utf8) ?? ""
        }
        let credential = URLCredential(user: username, password: password, persistence: .forSession)
        completionHandler(.useCredential, credential)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let host = request.url?.host(), let scheme = request.url?.scheme,
              host.caseInsensitiveCompare(expectedHost) == .orderedSame,
              scheme.caseInsensitiveCompare(expectedScheme) == .orderedSame else {
            var secureRequest = request
            secureRequest.setValue(nil, forHTTPHeaderField: "Authorization")
            completionHandler(secureRequest)
            return
        }
        completionHandler(request)
    }
}

func saveFolderURL(
    _ url: URL,
    provider: SettingsSyncProvider,
    defaults: UserDefaults = .standard
) throws {
    let bookmarkData = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )

    defaults.set(bookmarkData, forKey: SettingsSyncDefaults.folderBookmarkKey(for: provider))
    defaults.set(url.path, forKey: SettingsSyncDefaults.folderPathKey(for: provider))
}
