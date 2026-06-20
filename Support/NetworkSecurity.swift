import Foundation
import Network

private final class LockedResult<Value> {
    private let lock = NSLock()
    private var storedValue: Value?

    var value: Value? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }
}

enum NetworkSecurity {
    internal static var resolvConfPath = "/etc/resolv.conf"

    private static let cacheLock = NSLock()
    private static let cacheLifetime: TimeInterval = 60
    #if DEBUG
    internal static var readTimeout: TimeInterval = 2.0
    #else
    internal static var readTimeout: TimeInterval = 2.0
    #endif

    private static var domainCache: [String: (domains: [String], timestamp: Date)] = [:]

    internal static func resetResolvDomainCacheForTesting() {
        cacheLock.lock()
        domainCache.removeAll()
        cacheLock.unlock()
    }

    private static func getResolvDomains(for path: String) -> [String] {
        cacheLock.lock()

        let now = Date()
        if let cached = domainCache[path], now.timeIntervalSince(cached.timestamp) < cacheLifetime {
            cacheLock.unlock()
            return cached.domains
        }

        let cachedDomains = domainCache[path]?.domains ?? []
        cacheLock.unlock()

        guard let parsedDomains = loadResolvDomains(from: path, timeout: readTimeout) else {
            return cachedDomains
        }

        cacheLock.lock()
        domainCache[path] = (domains: parsedDomains, timestamp: Date())
        cacheLock.unlock()

        return parsedDomains
    }

    private static func loadResolvDomains(from path: String, timeout: TimeInterval) -> [String]? {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedResult<[String]>()

        DispatchQueue.global(qos: .default).async {
            result.value = parseResolvDomains(from: path)
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            return nil
        }
        return result.value
    }

    private static func parseResolvDomains(from path: String) -> [String] {
        var parsedDomains: [String] = []
        if let handle = FileHandle(forReadingAtPath: path) {
            defer { try? handle.close() }
            guard let data = try? handle.readToEnd(), let resolvData = String(data: data, encoding: .utf8) else {
                return parsedDomains
            }

            for line in resolvData.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("search ") || trimmed.hasPrefix("search\t") {
                    for substr in trimmed.dropFirst(6).split(whereSeparator: { $0.isWhitespace }) {
                        parsedDomains.append(String(substr))
                    }
                } else if trimmed.hasPrefix("domain ") || trimmed.hasPrefix("domain\t") {
                    parsedDomains.append(String(trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)))
                }
            }
        }
        return parsedDomains
    }

    static func isLocalHost(_ host: String, resolvConfPath: String = resolvConfPath) -> Bool {
        var cleanHost = host
        if cleanHost.hasPrefix("[") && cleanHost.hasSuffix("]") {
            cleanHost = String(cleanHost.dropFirst().dropLast())
        }

        let isCanonicalDecimal = cleanHost == "0" ||
            (!cleanHost.hasPrefix("0") && cleanHost.allSatisfy { $0.isASCII && $0.isNumber })
        if isCanonicalDecimal, UInt32(cleanHost) == nil {
            return false
        }

        if let ipv4 = IPv4Address(cleanHost) {
            let bytes = ipv4.rawValue
            return bytes[0] == 0 ||
                   bytes[0] == 10 ||
                   (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
                   (bytes[0] == 192 && bytes[1] == 168) ||
                   bytes[0] == 127 ||
                   (bytes[0] == 169 && bytes[1] == 254)
        }

        if let ipv6 = IPv6Address(cleanHost) {
            if ipv6 == IPv6Address.loopback {
                return true
            }

            let bytes = ipv6.rawValue

            let isUnspecified = bytes.allSatisfy { $0 == 0 }
            if isUnspecified {
                return true
            }

            let isIPv4Mapped = bytes[0...9].allSatisfy({ $0 == 0 }) && bytes[10] == 0xFF && bytes[11] == 0xFF
            // Note: IPv4-compatible addresses (::x.x.x.x) are obsolete per RFC 4291, but handled here for safety
            let isIPv4Compatible = bytes[0...11].allSatisfy({ $0 == 0 })

            if isIPv4Mapped || isIPv4Compatible {
                return bytes[12] == 0 ||
                       bytes[12] == 10 ||
                       (bytes[12] == 172 && bytes[13] >= 16 && bytes[13] <= 31) ||
                       (bytes[12] == 192 && bytes[13] == 168) ||
                       bytes[12] == 127 ||
                       (bytes[12] == 169 && bytes[13] == 254)
            }

            // Block loopback, unique local, link-local, and multicast (to prevent SSRF via mdns/bonjour)
            return bytes[0] == 0xFC || bytes[0] == 0xFD || bytes[0] == 0xFE || bytes[0] == 0xFF
        }

        if cleanHost.allSatisfy({ $0.isASCII && $0.isNumber }) || cleanHost.lowercased().hasPrefix("0x") {
            return false
        }

        if Int64(cleanHost) != nil || (cleanHost.lowercased().hasPrefix("0x") && Int64(cleanHost.dropFirst(2), radix: 16) != nil) {
            return false
        }

        if !cleanHost.contains(".") || cleanHost == "localhost" || cleanHost.hasSuffix(".local") {
            return true
        }

        let resolvURL = URL(fileURLWithPath: resolvConfPath)
        let standardizedPath = resolvURL.resolvingSymlinksInPath().path

        let isDefaultPath = standardizedPath == "/etc/resolv.conf" || standardizedPath == "/private/etc/resolv.conf"
        let tempDir = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path).resolvingSymlinksInPath().path

        let isTempPath = standardizedPath.hasPrefix(tempDir + "/") || standardizedPath == tempDir
        guard isDefaultPath || isTempPath else {
            return false
        }

        let domains = getResolvDomains(for: standardizedPath)
        for domain in domains {
            if cleanHost.hasSuffix("." + domain) || cleanHost == domain {
                return true
            }
        }

        return false
    }
}
