import Foundation
@testable import ScrutinyMonitor

let defaults = UserDefaults(suiteName: "BenchmarkSuite")!
let persistence = InstallationPersistence(userDefaults: defaults)

// Create 100 mock installations
var installations: [ScrutinyInstallation] = []
for i in 0..<100 {
    installations.append(ScrutinyInstallation(name: "Test \(i)", baseURL: URL(string: "http://localhost")!, apiToken: "token-\(i)"))
}

persistence.save(installations)
