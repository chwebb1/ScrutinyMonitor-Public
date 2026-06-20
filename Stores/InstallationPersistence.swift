import Foundation

struct InstallationPersistence {
    static let installationsKey = "ScrutinyMonitor.installations"

    private let key = Self.installationsKey
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let userDefaults: UserDefaults

    private static let cacheLock = NSLock()
    private static var cachedData: Data?
    private static var cachedInstallations: [ScrutinyInstallation]?

    init(userDefaults: UserDefaults = .shared, migratesLegacyDefaults: Bool = true) {
        self.userDefaults = userDefaults

        guard migratesLegacyDefaults else { return }

        // Seamless migration of installations and preferences from standard to shared suite
        let standard = UserDefaults.standard
        if userDefaults != standard {
            if userDefaults.data(forKey: Self.installationsKey) == nil,
               let legacyData = standard.data(forKey: Self.installationsKey) {
                userDefaults.set(legacyData, forKey: Self.installationsKey)
            }

            let preferenceKeys = [
                "ScrutinyMonitor.autoRefreshEnabled",
                "ScrutinyMonitor.autoRefreshInterval",
                "ScrutinyMonitor.driveFailureNotificationsEnabled",
                "ScrutinyMonitor.desktopNotificationsEnabled",
                "ScrutinyMonitor.showMenuBarExtra"
            ]
            for key in preferenceKeys {
                if userDefaults.object(forKey: key) == nil,
                   let val = standard.object(forKey: key) {
                    userDefaults.set(val, forKey: key)
                }
            }
        }
    }

    func load() -> [ScrutinyInstallation] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        Self.cacheLock.lock()
        if data == Self.cachedData, let cached = Self.cachedInstallations {
            Self.cacheLock.unlock()
            return cached
        }
        Self.cacheLock.unlock()

        var loadedInstallations = (try? decoder.decode([ScrutinyInstallation].self, from: data)) ?? []
        var needsSave = false

        let allTokens = KeychainHelper.shared.readAllData(service: key)

        for i in 0..<loadedInstallations.count {
            let id = loadedInstallations[i].id.uuidString
            if let tokenData = allTokens[id] {
                loadedInstallations[i].apiToken = tokenData
            } else if !loadedInstallations[i].apiToken.isEmpty {
                // Migrate from UserDefaults to Keychain
                needsSave = true
            }
        }

        if needsSave {
            save(loadedInstallations)
        }

        Self.cacheLock.lock()
        Self.cachedData = data
        Self.cachedInstallations = loadedInstallations
        Self.cacheLock.unlock()

        return loadedInstallations
    }

    func save(_ installations: [ScrutinyInstallation]) {
        let serviceKey = self.key

        Task.detached {
            let existingTokens = KeychainHelper.shared.readAllData(service: serviceKey)

            await withTaskGroup(of: Void.self) { group in
                for installation in installations {
                    group.addTask {
                        let existingToken = existingTokens[installation.id.uuidString]

                        if !installation.apiToken.isEmpty {
                            if existingToken != installation.apiToken {
                                KeychainHelper.shared.saveData(installation.apiToken, service: serviceKey, account: installation.id.uuidString, accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
                            }
                        } else {
                            if existingToken != nil {
                                KeychainHelper.shared.delete(service: serviceKey, account: installation.id.uuidString)
                            }
                        }
                    }
                }
            }
        }

        var safeInstallations = installations
        for i in 0..<safeInstallations.count {
            safeInstallations[i].apiToken = Data()
        }

        guard let data = try? encoder.encode(safeInstallations) else { return }
        userDefaults.set(data, forKey: key)

        Self.cacheLock.lock()
        Self.cachedData = data
        Self.cachedInstallations = installations
        Self.cacheLock.unlock()
    }

    func deleteToken(for id: UUID) {
        KeychainHelper.shared.delete(service: key, account: id.uuidString)
    }

    func deleteTokens(for ids: some Sequence<UUID>) {
        let serviceKey = self.key
        let stringIDs = ids.map { $0.uuidString }
        guard !stringIDs.isEmpty else { return }

        Task.detached {
            KeychainHelper.shared.delete(service: serviceKey, accounts: stringIDs)
        }
    }
}
