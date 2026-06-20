//
//  OverviewTotals.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//


struct OverviewTotals: Equatable, Codable {
    var installationCount: Int = 0
    var driveCount: Int = 0
    var passedCount: Int = 0
    var warningCount: Int = 0
    var failedCount: Int = 0
    var offlineCount: Int = 0

    static let zero = OverviewTotals()

    init(installationCount: Int = 0, driveCount: Int = 0, passedCount: Int = 0, warningCount: Int = 0, failedCount: Int = 0, offlineCount: Int = 0) {
        self.installationCount = installationCount
        self.driveCount = driveCount
        self.passedCount = passedCount
        self.warningCount = warningCount
        self.failedCount = failedCount
        self.offlineCount = offlineCount
    }

    init(installations: [ScrutinyInstallation]) {
        for installation in installations {
            self.installationCount += 1

            if installation.status == .offline {
                self.offlineCount += 1
            }

            if let snapshot = installation.lastSnapshot {
                self.driveCount += snapshot.totalDrives
                self.passedCount += snapshot.healthyDrives
                self.warningCount += snapshot.warningDrives
                self.failedCount += snapshot.criticalDrives
            }
        }
    }

    mutating func add(_ other: OverviewTotals) {
        installationCount += other.installationCount
        driveCount += other.driveCount
        passedCount += other.passedCount
        warningCount += other.warningCount
        failedCount += other.failedCount
        offlineCount += other.offlineCount
    }

    static func + (lhs: OverviewTotals, rhs: OverviewTotals) -> OverviewTotals {
        var result = lhs
        result += rhs
        return result
    }

    static func += (lhs: inout OverviewTotals, rhs: OverviewTotals) {
        lhs.add(rhs)
    }
}
