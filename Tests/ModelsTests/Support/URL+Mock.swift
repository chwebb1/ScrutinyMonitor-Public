import Foundation

extension URL {
    /// A helper method to create a deterministic URL for mocking in tests.
    /// This method explicitly force-unwraps the URL to fail fast on invalid inputs, 
    /// which aligns with the fail-fast principle for test setup.
    static func mock(_ string: String) -> URL {
        return URL(string: string)!
    }
}
