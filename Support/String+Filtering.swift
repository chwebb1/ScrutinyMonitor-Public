import Foundation

extension String {
    /// Returns a new string with all Unicode control characters removed.
    func removingControlCharacters() -> String {
        String(String.UnicodeScalarView(unicodeScalars.lazy.filter { $0.properties.generalCategory != .control }))
    }
}