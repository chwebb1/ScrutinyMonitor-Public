import Foundation

extension Error {
    var secureDescription: String {
        if let scrutinyError = self as? ScrutinyClientError {
            return scrutinyError.localizedDescription
        }

        if let validationError = self as? InstallationValidationError {
            return validationError.localizedDescription
        }

        if let syncError = self as? SettingsSyncError {
            return syncError.localizedDescription
        }

        if let urlError = nestedURLError {
            return "A network connection error occurred while communicating with the server (Code: \(urlError.code.rawValue))."
        }

        return "An unexpected error occurred. Please try again."
    }

    private var nestedURLError: URLError? {
        if let urlError = self as? URLError {
            return urlError
        }

        let underlyingError = (self as NSError).userInfo[NSUnderlyingErrorKey] as? Error
        return underlyingError?.nestedURLError
    }
}
