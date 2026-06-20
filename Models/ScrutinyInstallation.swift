import Foundation

struct ScrutinyInstallation: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var baseURL: URL {
        didSet {
            hostText = baseURL.host(percentEncoded: false) ?? baseURL.absoluteString
        }
    }
    var hostText: String = ""
    var apiToken: Data
    var lastSnapshot: InstallationSnapshot?
    var lastRefreshDate: Date?
    var lastError: String?
    var isRefreshing: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: URL,
        apiToken: Data = Data(),
        lastSnapshot: InstallationSnapshot? = nil,
        lastRefreshDate: Date? = nil,
        lastError: String? = nil,
        isRefreshing: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.hostText = baseURL.host(percentEncoded: false) ?? baseURL.absoluteString
        self.apiToken = apiToken
        self.lastSnapshot = lastSnapshot
        self.lastRefreshDate = lastRefreshDate
        self.lastError = lastError
        self.isRefreshing = isRefreshing
    }

    var status: InstallationStatus {
        if isRefreshing {
            return .refreshing
        }

        if lastError != nil {
            return .offline
        }

        return lastSnapshot?.status ?? .unknown
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case baseURL
        case apiToken
        case lastSnapshot
        case lastRefreshDate
        case lastError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(URL.self, forKey: .baseURL)
        hostText = baseURL.host(percentEncoded: false) ?? baseURL.absoluteString
        lastSnapshot = try container.decodeIfPresent(InstallationSnapshot.self, forKey: .lastSnapshot)
        lastRefreshDate = try container.decodeIfPresent(Date.self, forKey: .lastRefreshDate)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)

        self.apiToken = Self.decodeApiToken(from: container)
    }

    private static func decodeApiToken(from container: KeyedDecodingContainer<CodingKeys>) -> Data {
        if let token = try? container.decodeIfPresent(String.self, forKey: .apiToken),
           !token.isEmpty {
            return decodeStringToken(token)
        }

        guard let tokenData = try? container.decodeIfPresent(Data.self, forKey: .apiToken),
              !tokenData.isEmpty else {
            return Data()
        }

        return tokenData
    }

    private static func decodeStringToken(_ token: String) -> Data {
        guard let decodedData = Data(base64Encoded: token),
              decodedData.isLikelyTextToken else {
            return Data(token.utf8)
        }

        return decodedData
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(baseURL, forKey: .baseURL)
        // Deliberately DO NOT encode apiToken to UserDefaults for security reasons
        try container.encodeIfPresent(lastSnapshot, forKey: .lastSnapshot)
        try container.encodeIfPresent(lastRefreshDate, forKey: .lastRefreshDate)
        try container.encodeIfPresent(lastError, forKey: .lastError)
    }
}

private extension Data {
    var isLikelyTextToken: Bool {
        guard let token = String(data: self, encoding: .utf8), !token.isEmpty else {
            return false
        }

        return token.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        }
    }
}

enum InstallationStatus: String, Codable, CaseIterable {
    case healthy
    case warning
    case critical
    case offline
    case refreshing
    case empty
    case unknown

    var label: String {
        switch self {
        case .healthy: "Healthy"
        case .warning: "Warning"
        case .critical: "Critical"
        case .offline: "Offline"
        case .refreshing: "Refreshing"
        case .empty: "No Drives"
        case .unknown: "Unknown"
        }
    }
}
