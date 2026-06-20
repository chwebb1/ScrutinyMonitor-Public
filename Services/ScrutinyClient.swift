import Foundation
import os

struct ScrutinyClient: Sendable {
    static let shared = ScrutinyClient()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScrutinyMonitor", category: "ScrutinyClient")

    private let session: URLSession
    private let sleepFunction: @Sendable (UInt64) async throws -> Void

    internal init(sessionConfiguration: URLSessionConfiguration? = nil, sleepFunction: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        // 🛡️ Sentinel: Use ephemeral configuration to avoid caching sensitive API responses to disk
        let configuration = (sessionConfiguration?.copy() as? URLSessionConfiguration) ?? URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
        self.sleepFunction = sleepFunction
    }

    func fetchSnapshot(for installation: ScrutinyInstallation) async throws -> InstallationSnapshot {
        async let health = fetchHealth(for: installation)
        async let summary = fetchSummary(for: installation)

        let (healthResponse, summaryResponse) = try await (health, summary)
        return try makeSnapshot(health: healthResponse, summary: summaryResponse)
    }

    func fetchDriveDetail(for drive: DriveSnapshot, installation: ScrutinyInstallation) async throws -> DriveDetail {
        let url = try makeDriveDetailURL(driveID: drive.id, installation: installation)

        let response: DriveDetailResponse = try await request(
            url: url,
            installation: installation
        )

        guard response.success else {
            throw ScrutinyClientError.api(response.error ?? response.errors?.joined(separator: ", ") ?? "Drive details request failed.")
        }

        guard let data = response.data else {
            throw ScrutinyClientError.api("The server did not return drive details.")
        }

        return DriveDetail(
            id: drive.id,
            device: data.device,
            history: data.smartResults,
            metadata: response.metadata ?? [:]
        )
    }

    private func makeDriveDetailURL(driveID: String, installation: ScrutinyInstallation) throws -> URL {
        guard !driveID.isEmpty else {
            throw ScrutinyClientError.api("Drive ID cannot be empty.")
        }
        guard !driveID.contains("..") else {
            throw ScrutinyClientError.api("Invalid drive ID format.")
        }
        
        return installation.baseURL
            .appendingScrutinyEndpoint("/api/device")
            .appending(component: driveID)
            .appending(component: "details")
    }

    private func fetchHealth(for installation: ScrutinyInstallation) async throws -> HealthResponse {
        let url = installation.baseURL.appendingScrutinyEndpoint("/api/health")
        return try await request(url: url, installation: installation)
    }

    private func fetchSummary(for installation: ScrutinyInstallation) async throws -> SummaryResponse {
        let url = installation.baseURL.appendingScrutinyEndpoint("/api/summary")
        return try await request(url: url, installation: installation)
    }

    private static let retryBaseDelayNanoseconds: UInt64 = 750_000_000
    private static let maxRetryAttempts = 3

    private func request<Response: Decodable>(url: URL, installation: ScrutinyInstallation) async throws -> Response {
        var lastError: Error?

        for attempt in 0..<Self.maxRetryAttempts {
            do {
                return try await requestOnce(url: url, installation: installation)
            } catch {
                lastError = error

                guard error.isTransientNetworkError, attempt < Self.maxRetryAttempts - 1 else {
                    throw error
                }

                try await sleepFunction(UInt64(attempt + 1) * Self.retryBaseDelayNanoseconds)
            }
        }

        // This throw is technically unreachable but required to satisfy the compiler's flow analysis
        throw lastError ?? ScrutinyClientError.invalidResponse
    }

    private func requestOnce<Response: Decodable>(url: URL, installation: ScrutinyInstallation) async throws -> Response {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var authDelegate: ScrutinyAuthDelegate?

        if !installation.apiToken.isEmpty {
            guard installation.apiToken.count <= 8192 else {
                throw ScrutinyClientError.api("Invalid API token format.")
            }
            let secureTokenData = SecureData(trimmingASCIIWhitespace: installation.apiToken)
            if !secureTokenData.isEmpty {
                let isValid = secureTokenData.withUnsafeBytes { buffer -> Bool in
                    var utf8Decoder = Unicode.UTF8()
                    var iterator = buffer.makeIterator()
                    var characterCount = 0
                    while true {
                        switch utf8Decoder.decode(&iterator) {
                        case .scalarValue(let scalar):
                            characterCount += 1
                            if characterCount > 4096 { return false }
                            let v = scalar.value
                            // Block C0 (0x00-0x1F), DEL (0x7F), and C1 (0x80-0x9F) controls.
                            if v <= 0x1F || (v >= 0x7F && v <= 0x9F) {
                                return false
                            }
                        case .emptyInput:
                            return true
                        case .error:
                            return false
                        }
                    }
                }
                
                guard isValid else {
                    throw ScrutinyClientError.api("Invalid API token format.")
                }

                if let scheme = url.scheme, scheme.lowercased() == "http" {
                    guard let host = url.host, NetworkSecurity.isLocalHost(host) else {
                        throw ScrutinyClientError.api("Insecure connection: API token cannot be sent over plain HTTP to a public server.")
                    }
                }

                // SECURITY: URLRequest inherently requires a String for HTTP headers.
                // This means the cleartext token will temporarily exist as a String on the heap
                // and cannot be deterministically zeroized. This is a known Foundation API limitation.
                secureTokenData.withUnsafeBytes { buffer in
                    if let token = String(bytes: buffer, encoding: .utf8) {
                        request.setValue(token, forHTTPHeaderField: "X-API-Key")
                    }
                }

                if let host = url.host, let scheme = url.scheme {
                    authDelegate = ScrutinyAuthDelegate(
                        expectedHost: host,
                        expectedScheme: scheme,
                        secureTokenData: secureTokenData
                    )
                }
            }
        }

        let (data, response) = try await session.data(for: request, delegate: authDelegate)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScrutinyClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw ScrutinyClientError.httpStatus(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Response.self, from: data)
        } catch {
            Self.logger.error("Decoding error for \(Response.self, privacy: .public): \(error, privacy: .private)")
            throw ScrutinyClientError.decoding(error)
        }
    }

    private func makeSnapshot(health: HealthResponse, summary: SummaryResponse) throws -> InstallationSnapshot {
        if !health.success {
            throw ScrutinyClientError.api(health.error ?? health.errors?.joined(separator: ", ") ?? "Health check failed.")
        }

        if !summary.success {
            throw ScrutinyClientError.api(summary.error ?? summary.errors?.joined(separator: ", ") ?? "Summary request failed.")
        }

        let summaryData = summary.data?.summary ?? [:]
        var devices = [DriveSnapshot]()
        devices.reserveCapacity(summaryData.count)

        for (key, entry) in summaryData {
            devices.append(DriveSnapshot(key: key, entry: entry))
        }

        devices.sort { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        var healthy = 0
        var warning = 0
        var critical = 0

        for device in devices {
            switch device.status {
            case .passed:
                healthy += 1
            case .warning:
                warning += 1
            case .failed:
                critical += 1
            case .unknown:
                break
            }
        }

        return InstallationSnapshot(
            healthOK: health.success,
            totalDrives: devices.count,
            healthyDrives: healthy,
            warningDrives: warning,
            criticalDrives: critical,
            devices: devices,
            collectedAt: Date()
        )
    }
}

extension Error {
    var isTransientNetworkError: Bool {
        guard let urlError = self as? URLError else {
            return false
        }

        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .timedOut,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}

final class ScrutinyAuthDelegate: NSObject, URLSessionTaskDelegate {
    let expectedHost: String
    let expectedScheme: String
    private let secureTokenData: SecureData

    init(expectedHost: String, expectedScheme: String, secureTokenData: SecureData) {
        self.expectedHost = expectedHost
        self.expectedScheme = expectedScheme
        self.secureTokenData = secureTokenData
        super.init()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authMethod = challenge.protectionSpace.authenticationMethod
        if (authMethod == NSURLAuthenticationMethodHTTPBasic || authMethod == NSURLAuthenticationMethodHTTPDigest), challenge.previousFailureCount == 0 {
            guard challenge.protectionSpace.host.caseInsensitiveCompare(expectedHost) == .orderedSame else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            guard let proto = challenge.protectionSpace.protocol, proto.caseInsensitiveCompare(expectedScheme) == .orderedSame else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            // Security Limitation: URLCredential inherently requires a String. This means the
            // cleartext password/token will temporarily exist as a String on the heap and cannot be
            // deterministically zeroized. This is a known Foundation API limitation.
            let credential = secureTokenData.withUnsafeBytes { buffer -> URLCredential? in
                guard let token = String(bytes: buffer, encoding: .utf8) else { return nil }
                return URLCredential(user: "", password: token, persistence: .forSession)
            }
            guard let credential = credential else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            completionHandler(.useCredential, credential)
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let host = request.url?.host, let scheme = request.url?.scheme,
              host.caseInsensitiveCompare(expectedHost) == .orderedSame,
              scheme.caseInsensitiveCompare(expectedScheme) == .orderedSame else {
            var secureRequest = request
            secureRequest.setValue(nil, forHTTPHeaderField: "Authorization")
            secureRequest.setValue(nil, forHTTPHeaderField: "X-API-Key")
            completionHandler(secureRequest)
            return
        }
        completionHandler(request)
    }
}

private extension DriveSnapshot {
    init(key: String, entry: SummaryEntry) {
        self.init(
            id: entry.device?.scrutinyUUID ?? entry.device?.wwn ?? key,
            name: entry.device?.deviceName ?? "Unknown device",
            model: entry.device?.modelName ?? entry.device?.manufacturer ?? "Unknown model",
            serial: entry.device?.serialNumber ?? "Unknown serial",
            protocolName: entry.device?.deviceProtocol ?? "Unknown",
            capacityBytes: entry.device?.capacity,
            statusCode: entry.device?.deviceStatus?.value,
            temperature: entry.smart?.temp?.value,
            powerOnHours: entry.smart?.powerOnHours?.value,
            collectorDate: entry.smart?.collectorDate
        )
    }
}

enum ScrutinyClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case api(String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server returned an invalid response."
        case .httpStatus(let status):
            "The server returned HTTP \(status)."
        case .api(let message):
            message
        case .decoding(_):
            "Could not read the Scrutiny response. The server returned an unexpected format."
        }
    }
}
// Revert note: Static JSONDecoder removed for concurrency safety
