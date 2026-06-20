// Usage: Run this script within the Xcode target or compile it manually
// (e.g., `swiftc benchmark_keychain.swift ...`) since it is excluded from the main executable target.
// Note: If running in automated CI/headless environments, ensure the macOS login keychain
// is unlocked or use a mock configuration, otherwise SecItemAdd operations will fail.
import Foundation
@testable import ScrutinyMonitor

let service = "ScrutinyMonitor.KeychainBenchmark"
let itemCount = Int(ProcessInfo.processInfo.environment["ITEM_COUNT"] ?? "100") ?? 100
let accounts = (0..<itemCount).map { "account-\($0)" }

func performCleanup() {
    let leftovers = KeychainHelper.shared.readAllData(service: service)
    KeychainHelper.shared.delete(service: service, accounts: Array(leftovers.keys))
}

func abortBenchmark(_ message: String) -> Never {
    print("Error: \(message)")
    print("Running emergency cleanup...")
    performCleanup()
    exit(1)
}

// 1. Initial cleanup to guarantee a clean state.
// (Also handles cleanup if a previous run was aborted via SIGINT or crash)
print("Cleaning up previous benchmark items...")
performCleanup()

// Ensure cleanup runs regardless of how the script exits normally
defer {
    performCleanup()
    print("Cleanup complete.")
}

// Setup: populate keychain
print("Populating keychain with \(itemCount) items...")
for (i, account) in accounts.enumerated() {
    guard let data = "token-\(i)".data(using: .utf8) else {
        abortBenchmark("Failed to encode token for account \(account)")
    }
    KeychainHelper.shared.saveData(data, service: service, account: account)
}

// Warmup run to eliminate cold-start/caching bias and validate setup
print("Running warmup...")
let warmupAll = KeychainHelper.shared.readAllData(service: service)
guard warmupAll.count == itemCount else {
    abortBenchmark("Setup validation failed: Expected \(itemCount) items, but warmup read \(warmupAll.count)")
}

let clock = SuspendingClock()

// Benchmark 1: Sequential Reads
print("Benchmarking Sequential Reads...")
var seqCheckCount = 0
let sequentialDuration = clock.measure {
    for account in accounts {
        if KeychainHelper.shared.readData(service: service, account: account) != nil {
            seqCheckCount += 1
        } else {
            print("Warning: Failed to read data for account \(account)")
        }
    }
}
guard seqCheckCount == itemCount else {
    abortBenchmark("Sequential read retrieved \(seqCheckCount)/\(itemCount) items")
}

let seqSeconds = Double(sequentialDuration.components.seconds) + Double(sequentialDuration.components.attoseconds) / 1e18
print(String(format: "Sequential Reads took: %.4f seconds", seqSeconds))

// Benchmark 2: Bulk Read
// CAUTION: Bulk reads load all matching keychain items into memory. 
// Do not use this pattern verbatim for unbounded production datasets.
print("Benchmarking Bulk Read...")
var bulkCheckCount = 0
let bulkDuration = clock.measure {
    let all = KeychainHelper.shared.readAllData(service: service)
    for account in accounts {
        if all[account] != nil {
            bulkCheckCount += 1
        } else {
            print("Warning: Failed to read data for account \(account) in bulk dictionary")
        }
    }
}
guard bulkCheckCount == itemCount else {
    abortBenchmark("Bulk read dictionary missing expected items (found \(bulkCheckCount)/\(itemCount))")
}

let bulkSeconds = Double(bulkDuration.components.seconds) + Double(bulkDuration.components.attoseconds) / 1e18
print(String(format: "Bulk Read took: %.4f seconds", bulkSeconds))

if bulkSeconds > 0 {
    let speedup = seqSeconds / bulkSeconds
    print(String(format: "Bulk read is %.2fx faster", speedup))
}
