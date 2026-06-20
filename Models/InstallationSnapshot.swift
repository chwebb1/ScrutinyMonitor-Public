import Foundation
import os

struct InstallationSnapshot: Codable, Hashable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScrutinyMonitor", category: "InstallationSnapshot")
    
    let healthOK: Bool
    let totalDrives: Int
    let healthyDrives: Int
    let warningDrives: Int
    let criticalDrives: Int
    let devices: [DriveSnapshot]
    let collectedAt: Date

    // ⚡ Bolt: Pre-calculate expensive derived properties (like O(N) loops over devices)
    // into stored properties to prevent redundant main-thread evaluation during view renders.
    let status: InstallationStatus
    let averageTemperature: Int?

    private enum CodingKeys: String, CodingKey {
        case healthOK, totalDrives, healthyDrives, warningDrives, criticalDrives, devices, collectedAt
    }

    init(healthOK: Bool, totalDrives: Int, healthyDrives: Int, warningDrives: Int, criticalDrives: Int, devices: [DriveSnapshot], collectedAt: Date) {
        self.healthOK = healthOK
        let sanitizedHealthy = max(0, healthyDrives)
        let sanitizedWarning = max(0, warningDrives)
        let sanitizedCritical = max(0, criticalDrives)
        let (sum1, overflow1) = sanitizedHealthy.addingReportingOverflow(sanitizedWarning)
        let (sum2, overflow2) = sum1.addingReportingOverflow(sanitizedCritical)
        let categorizedCount = (overflow1 || overflow2) ? Int.max : sum2
        
        if totalDrives < devices.count || totalDrives < categorizedCount || healthyDrives < 0 || warningDrives < 0 || criticalDrives < 0 {
            Self.logger.warning("Invalid drive counts detected, clamping to valid ranges")
        }
        
        self.totalDrives = max(totalDrives, devices.count, categorizedCount)
        self.healthyDrives = sanitizedHealthy
        self.warningDrives = sanitizedWarning
        self.criticalDrives = sanitizedCritical
        self.devices = devices
        self.collectedAt = collectedAt

        if !self.healthOK {
            self.status = .offline
        } else if self.criticalDrives > 0 {
            self.status = .critical
        } else if self.warningDrives > 0 {
            self.status = .warning
        } else if self.totalDrives == 0 {
            self.status = .empty
        } else {
            self.status = .healthy
        }

        var sum = 0
        var count = 0
        for device in devices {
            if let temp = device.temperature {
                let (newSum, overflowed) = sum.addingReportingOverflow(temp)
                if overflowed {
                    Self.logger.warning("Temperature accumulation overflowed")
                } else {
                    sum = newSum
                    count += 1
                }
            }
        }
        self.averageTemperature = count > 0 ? sum / count : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let healthOK = try container.decode(Bool.self, forKey: .healthOK)
        let totalDrives = try container.decode(Int.self, forKey: .totalDrives)
        let healthyDrives = try container.decode(Int.self, forKey: .healthyDrives)
        let warningDrives = try container.decode(Int.self, forKey: .warningDrives)
        let criticalDrives = try container.decode(Int.self, forKey: .criticalDrives)
        let devices = try container.decode([DriveSnapshot].self, forKey: .devices)
        let collectedAt = try container.decode(Date.self, forKey: .collectedAt)

        self.init(healthOK: healthOK, totalDrives: totalDrives, healthyDrives: healthyDrives, warningDrives: warningDrives, criticalDrives: criticalDrives, devices: devices, collectedAt: collectedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(healthOK, forKey: .healthOK)
        try container.encode(totalDrives, forKey: .totalDrives)
        try container.encode(healthyDrives, forKey: .healthyDrives)
        try container.encode(warningDrives, forKey: .warningDrives)
        try container.encode(criticalDrives, forKey: .criticalDrives)
        try container.encode(devices, forKey: .devices)
        try container.encode(collectedAt, forKey: .collectedAt)
    }
}


