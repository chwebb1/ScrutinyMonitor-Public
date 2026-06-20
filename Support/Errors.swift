import Foundation

public enum InstallationValidationError: LocalizedError, Equatable {
    case emptyURL
    case invalidURL
    case insecureURL
    case unsupportedScheme
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .emptyURL:
            "Enter the Scrutiny server URL."
        case .invalidURL:
            "Enter a valid URL such as http://nas.local:8080."
        case .insecureURL:
            "Public servers must use HTTPS."
        case .unsupportedScheme:
            "Scrutiny servers must use HTTP or HTTPS."
        case .invalidInput(let message):
            message
        }
    }
}

public enum SettingsSyncError: LocalizedError {
    case providerNotConfigured(SettingsSyncProvider)
    case invalidWebDAVURL
    case insecureWebDAVURL
    case inlineCredentialsNotSupported
    case passwordWithoutUsername
    case serverRejectedRequest(Int)
    case missingHTTPResponse
    case backendDeallocated

    public var errorDescription: String? {
        switch self {
        case .providerNotConfigured(let provider):
            "\(provider.displayName) is not configured."
        case .invalidWebDAVURL:
            "Enter a valid WebDAV folder URL."
        case .insecureWebDAVURL:
            "Public WebDAV servers must use HTTPS."
        case .inlineCredentialsNotSupported:
            "Credentials must be entered in the username and password fields. Please remove them from the URL."
        case .passwordWithoutUsername:
            "A username is required to save a password."
        case .serverRejectedRequest(let statusCode):
            "The sync server returned HTTP \(statusCode)."
        case .missingHTTPResponse:
            "The sync server returned an invalid response."
        case .backendDeallocated:
            "The sync backend was deallocated before the operation completed."
        }
    }
}
