import Foundation
import Security
import os

struct KeychainHelper {
    static let shared = KeychainHelper()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.chriswebb.ScrutinyMonitor", category: "KeychainHelper")
#if DEBUG
    private static let testFallback = KeychainTestFallback()

    /// Thread-safe container for test-only overrides of Security framework C functions.
    ///
    /// Set the appropriate closure before calling a `KeychainHelper` method under test,
    /// then clear state via `KeychainHelper.resetTestState()` in `tearDown()`.
    /// Pair with `forceRealImplementationForTesting = true` to bypass the in-memory
    /// `KeychainTestFallback` and route calls through these closures instead.
    final class KeychainTestOverrides: @unchecked Sendable {
        private let lock = NSLock()

        private var _forceRealImplementationForTesting = false
        /// Forces tests to bypass the in-memory fallback and use the real OS implementations.
        var forceRealImplementationForTesting: Bool {
            get { lock.withLock { _forceRealImplementationForTesting } }
            set { lock.withLock { _forceRealImplementationForTesting = newValue } }
        }

        private var _secItemAddOverride: (@Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus)?
        /// Mock for SecItemAdd
        var secItemAddOverride: (@Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus)? {
            get { lock.withLock { _secItemAddOverride } }
            set { lock.withLock { _secItemAddOverride = newValue } }
        }

        private var _secItemUpdateOverride: (@Sendable (CFDictionary, CFDictionary) -> OSStatus)?
        /// Mock for SecItemUpdate
        var secItemUpdateOverride: (@Sendable (CFDictionary, CFDictionary) -> OSStatus)? {
            get { lock.withLock { _secItemUpdateOverride } }
            set { lock.withLock { _secItemUpdateOverride = newValue } }
        }

        private var _secItemDeleteOverride: (@Sendable (CFDictionary) -> OSStatus)?
        /// Mock for SecItemDelete
        var secItemDeleteOverride: (@Sendable (CFDictionary) -> OSStatus)? {
            get { lock.withLock { _secItemDeleteOverride } }
            set { lock.withLock { _secItemDeleteOverride = newValue } }
        }

        private var _secItemCopyMatchingOverride: (@Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus)?
        /// Mock for SecItemCopyMatching
        var secItemCopyMatchingOverride: (@Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus)? {
            get { lock.withLock { _secItemCopyMatchingOverride } }
            set { lock.withLock { _secItemCopyMatchingOverride = newValue } }
        }

        func reset() {
            lock.withLock {
                _forceRealImplementationForTesting = false
                _secItemAddOverride = nil
                _secItemUpdateOverride = nil
                _secItemDeleteOverride = nil
                _secItemCopyMatchingOverride = nil
            }
        }
    }

    /// Thread-safe overrides for testing C-level security framework functions.
    static let overrides = KeychainTestOverrides()
#endif
    
    private init() {}
    
    func saveData(_ data: Data, service: String, account: String, accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly) {
#if DEBUG
        if Self.shouldUseTestFallback {
            Self.testFallback.save(data, service: service, account: account)
            return
        }
#endif
        
        let status = addKeychainItem(data, service: service, account: account, accessibility: accessibility)
        
        if status == errSecDuplicateItem {
            updateExistingItem(data, service: service, account: account, accessibility: accessibility)
        } else if status != errSecSuccess {
            Self.logger.error("Failed to add item to keychain. Status: \(status, privacy: .public)")
        }
    }
    
    private func addKeychainItem(_ data: Data, service: String, account: String, accessibility: CFString) -> OSStatus {
        let query: [String: Any] = [
            kSecValueData as String: data,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: accessibility
        ]
        
#if DEBUG
        if let override = Self.overrides.secItemAddOverride {
            return override(query as CFDictionary, nil)
        }
#endif
        return SecItemAdd(query as CFDictionary, nil)
    }
    
    private func updateExistingItem(_ data: Data, service: String, account: String, accessibility: CFString) {
        let updateQuery: [String: Any] = [
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecClass as String: kSecClassGenericPassword
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        
#if DEBUG
        let updateStatus = Self.overrides.secItemUpdateOverride?(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            ?? SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
#else
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
#endif
        if updateStatus != errSecSuccess {
            // If update fails (e.g. changing accessibility attribute might return errSecParam),
            // try deleting and re-adding.
#if DEBUG
            _ = Self.overrides.secItemDeleteOverride?(updateQuery as CFDictionary)
                ?? SecItemDelete(updateQuery as CFDictionary)
#else
            SecItemDelete(updateQuery as CFDictionary)
#endif
            let retryStatus = addKeychainItem(data, service: service, account: account, accessibility: accessibility)
            if retryStatus != errSecSuccess {
                Self.logger.error("Failed to add item to keychain after update failure. Status: \(retryStatus, privacy: .public)")
            }
        }
    }
    
    func readData(service: String, account: String) -> Data? {
#if DEBUG
        if Self.shouldUseTestFallback {
            return Self.testFallback.read(service: service, account: account)
        }
#endif
        
        let query: [String: Any] = [
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
#if DEBUG
        let status = Self.overrides.secItemCopyMatchingOverride?(query as CFDictionary, &result)
            ?? SecItemCopyMatching(query as CFDictionary, &result)
#else
        let status = SecItemCopyMatching(query as CFDictionary, &result)
#endif
        
        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        

        return nil
    }
    
    func readAllData(service: String) -> [String: Data] {
#if DEBUG
        if Self.shouldUseTestFallback {
            return Self.testFallback.readAllData(service: service)
        }
#endif
        
        let query: [String: Any] = [
            kSecAttrService as String: service,
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
#if DEBUG
        let status = Self.overrides.secItemCopyMatchingOverride?(query as CFDictionary, &result)
            ?? SecItemCopyMatching(query as CFDictionary, &result)
#else
        let status = SecItemCopyMatching(query as CFDictionary, &result)
#endif
        
        var items: [String: Data] = [:]
        
        if status == errSecSuccess, let array = result as? [[String: Any]] {
            for item in array {
                if let account = item[kSecAttrAccount as String] as? String,
                   let data = item[kSecValueData as String] as? Data {
                    items[account] = data
                }
            }
        }
        

        return items
    }
    
    func delete(service: String, account: String) {
#if DEBUG
        if Self.shouldUseTestFallback {
            Self.testFallback.delete(service: service, account: account)
            return
        }
#endif
        
        let query: [String: Any] = [
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecClass as String: kSecClassGenericPassword
        ]
        
#if DEBUG
        let status = Self.overrides.secItemDeleteOverride?(query as CFDictionary)
            ?? SecItemDelete(query as CFDictionary)
#else
        let status = SecItemDelete(query as CFDictionary)
#endif
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.logger.error("Failed to delete item from keychain. Status: \(status, privacy: .public)")
        }
    }
    
    func delete(service: String, accounts: [String]) {
        guard !accounts.isEmpty else { return }
#if DEBUG
        if Self.shouldUseTestFallback {
            Self.testFallback.delete(service: service, accounts: accounts)
            return
        }
#endif
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnPersistentRef as String: true
        ]
        
        var result: AnyObject?
#if DEBUG
        let status = Self.overrides.secItemCopyMatchingOverride?(query as CFDictionary, &result)
            ?? SecItemCopyMatching(query as CFDictionary, &result)
#else
        let status = SecItemCopyMatching(query as CFDictionary, &result)
#endif
        
        if status == errSecSuccess {
            guard let array = result as? [[String: Any]] else {
                Self.logger.error("Failed to cast keychain query result to expected array type.")
                return
            }
            let accountsSet = Set(accounts)
            var itemsToDelete = [Data]()
            itemsToDelete.reserveCapacity(accounts.count)
            let accountKey = kSecAttrAccount as String
            let refKey = kSecValuePersistentRef as String
            for item in array {
                if let account = item[accountKey] as? String,
                   accountsSet.contains(account),
                   let ref = item[refKey] as? Data {
                    itemsToDelete.append(ref)
                }
            }

            if !itemsToDelete.isEmpty {
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecMatchItemList as String: itemsToDelete
                ]
#if DEBUG
                let deleteStatus = Self.overrides.secItemDeleteOverride?(deleteQuery as CFDictionary)
                    ?? SecItemDelete(deleteQuery as CFDictionary)
#else
                let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
#endif
                if deleteStatus != errSecSuccess {
                    Self.logger.error("Failed to batch delete items from keychain. Status: \(deleteStatus, privacy: .public)")
                }
            }
        } else if status != errSecItemNotFound {
            Self.logger.error("Failed to copy items for batch deletion. Status: \(status, privacy: .public)")
        }
    }
    
#if DEBUG
    private static var shouldUseTestFallback: Bool {
        if Self.overrides.forceRealImplementationForTesting { return false }
        return NSClassFromString("XCTestCase") != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    public static func resetTestState() {
        Self.testFallback.reset()
        Self.overrides.reset()
    }
#endif
    


#if DEBUG
    private final class KeychainTestFallback {
        private var storage: [String: Data] = [:]
        private let lock = NSLock()
        
        func save(_ data: Data, service: String, account: String) {
            lock.withLock {
                storage[key(service: service, account: account)] = data
            }
        }
        
        func reset() {
            lock.withLock {
                storage.removeAll()
            }
        }

        func read(service: String, account: String) -> Data? {
            lock.withLock {
                storage[key(service: service, account: account)]
            }
        }
        
        func readAllData(service: String) -> [String: Data] {
            lock.withLock {
                let prefix = "\(service)\u{1f}"
                var items = [String: Data]()
                for (key, value) in storage {
                    if key.hasPrefix(prefix) {
                        let account = String(key.dropFirst(prefix.count))
                        items[account] = value
                    }
                }
                return items
            }
        }
        
        func delete(service: String, account: String) {
            lock.withLock {
                _ = storage.removeValue(forKey: key(service: service, account: account))
            }
        }
        
        func delete(service: String, accounts: [String]) {
            lock.withLock {
                for account in accounts {
                    storage.removeValue(forKey: key(service: service, account: account))
                }
            }
        }
        
        private func key(service: String, account: String) -> String {
            "\(service)\u{1f}\(account)"
        }
    }
#endif
}
