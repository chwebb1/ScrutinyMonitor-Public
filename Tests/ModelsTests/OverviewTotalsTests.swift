import XCTest
@testable import ScrutinyMonitor

final class OverviewTotalsTests: XCTestCase {

    func testEquatable() {
        let a = OverviewTotals(installationCount: 1, driveCount: 2, passedCount: 3, warningCount: 4, failedCount: 5, offlineCount: 6)
        let b = OverviewTotals(installationCount: 1, driveCount: 2, passedCount: 3, warningCount: 4, failedCount: 5, offlineCount: 6)
        XCTAssertEqual(a, b)
    }
    func testCodable() throws {
        let original = OverviewTotals(installationCount: 1, driveCount: 2, passedCount: 3, warningCount: 4, failedCount: 5, offlineCount: 6)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OverviewTotals.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testOverviewTotalsWithEmptyInstallations() {
        let totals = OverviewTotals(installations: [])

        XCTAssertEqual(totals.installationCount, 0)
        XCTAssertEqual(totals.driveCount, 0)
        XCTAssertEqual(totals.passedCount, 0)
        XCTAssertEqual(totals.warningCount, 0)
        XCTAssertEqual(totals.failedCount, 0)
        XCTAssertEqual(totals.offlineCount, 0)
    }

    func testOverviewTotalsEdgeCases() {
        let snapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 10,
            healthyDrives: 8,
            warningDrives: 1,
            criticalDrives: 1,
            devices: [],
            collectedAt: Date(timeIntervalSince1970: 0)
        )

        // 1. Unknown status (no snapshot, no error, not refreshing)
        let unknownInstallation = ScrutinyInstallation(
            name: "Unknown Server",
            baseURL: URL.mock("http://unknown.local")
        )
        XCTAssertEqual(unknownInstallation.status, .unknown)

        // 2. Refreshing status (no snapshot)
        let refreshingInstallation = ScrutinyInstallation(
            name: "Refreshing Server",
            baseURL: URL.mock("http://refreshing.local"),
            isRefreshing: true
        )
        XCTAssertEqual(refreshingInstallation.status, .refreshing)

        // 3. Offline but has lastSnapshot
        let offlineWithSnapshotInstallation = ScrutinyInstallation(
            name: "Offline With Snapshot",
            baseURL: URL.mock("http://offline-snapshot.local"),
            lastSnapshot: snapshot,
            lastError: "Timeout"
        )
        XCTAssertEqual(offlineWithSnapshotInstallation.status, .offline)

        // 4. Refreshing but has lastSnapshot
        let refreshingWithSnapshotInstallation = ScrutinyInstallation(
            name: "Refreshing With Snapshot",
            baseURL: URL.mock("http://refreshing-snapshot.local"),
            lastSnapshot: snapshot,
            isRefreshing: true
        )
        XCTAssertEqual(refreshingWithSnapshotInstallation.status, .refreshing)

        let totals = OverviewTotals(installations: [unknownInstallation, refreshingInstallation, offlineWithSnapshotInstallation, refreshingWithSnapshotInstallation])

        XCTAssertEqual(totals.installationCount, 4)
        XCTAssertEqual(totals.offlineCount, 1) // Only offlineWithSnapshotInstallation is offline

        // Both offlineWithSnapshotInstallation and refreshingWithSnapshotInstallation have snapshots
        XCTAssertEqual(totals.driveCount, 20)
        XCTAssertEqual(totals.passedCount, 16)
        XCTAssertEqual(totals.warningCount, 2)
        XCTAssertEqual(totals.failedCount, 2)
    }

    func testOverviewTotalsWithMixedInstallations() {
        // 1. Offline installation without snapshot
        let offlineInstallation = ScrutinyInstallation(
            name: "Offline Server",
            baseURL: URL.mock("http://offline.local"),
            lastError: "Connection timeout"
        )
        // Ensure the mock correctly resolves to offline based on status property logic
        XCTAssertEqual(offlineInstallation.status, .offline)

        // 2. Healthy installation with valid snapshot
        let healthySnapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 5,
            healthyDrives: 3,
            warningDrives: 1,
            criticalDrives: 1,
            devices: [],
            collectedAt: Date()
        )
        let healthyInstallation = ScrutinyInstallation(
            name: "Healthy Server",
            baseURL: URL.mock("http://healthy.local"),
            lastSnapshot: healthySnapshot
        )

        // 3. Another healthy installation with valid snapshot
        let secondSnapshot = InstallationSnapshot(
            healthOK: true,
            totalDrives: 2,
            healthyDrives: 2,
            warningDrives: 0,
            criticalDrives: 0,
            devices: [],
            collectedAt: Date()
        )
        let secondHealthyInstallation = ScrutinyInstallation(
            name: "Second Healthy Server",
            baseURL: URL.mock("http://second-healthy.local"),
            lastSnapshot: secondSnapshot
        )

        let installations = [offlineInstallation, healthyInstallation, secondHealthyInstallation]
        let totals = OverviewTotals(installations: installations)

        // Total installations
        XCTAssertEqual(totals.installationCount, 3)
        // 1 offline server
        XCTAssertEqual(totals.offlineCount, 1)
        // Drives sum: 5 + 2 = 7
        XCTAssertEqual(totals.driveCount, 7)
        // Passed sum: 3 + 2 = 5
        XCTAssertEqual(totals.passedCount, 5)
        // Warning sum: 1 + 0 = 1
        XCTAssertEqual(totals.warningCount, 1)
        // Failed sum: 1 + 0 = 1
        XCTAssertEqual(totals.failedCount, 1)
    }

    func testOverviewTotalsAdd() {
        var totals1 = OverviewTotals(
            installationCount: 5, driveCount: 20, passedCount: 15,
            warningCount: 3, failedCount: 2, offlineCount: 1
        )

        let totals2 = OverviewTotals(
            installationCount: 3, driveCount: 10, passedCount: 8,
            warningCount: 1, failedCount: 1, offlineCount: 0
        )

        totals1.add(totals2)

        XCTAssertEqual(totals1.installationCount, 8)
        XCTAssertEqual(totals1.driveCount, 30)
        XCTAssertEqual(totals1.passedCount, 23)
        XCTAssertEqual(totals1.warningCount, 4)
        XCTAssertEqual(totals1.failedCount, 3)
        XCTAssertEqual(totals1.offlineCount, 1)
    }

    func testOverviewTotalsOperators() {
        var totals1 = OverviewTotals(
            installationCount: 5, driveCount: 20, passedCount: 15,
            warningCount: 3, failedCount: 2, offlineCount: 1
        )

        let totals2 = OverviewTotals(
            installationCount: 3, driveCount: 10, passedCount: 8,
            warningCount: 1, failedCount: 1, offlineCount: 0
        )

        let sum = totals1 + totals2
        XCTAssertEqual(sum.installationCount, 8)
        XCTAssertEqual(sum.driveCount, 30)
        XCTAssertEqual(sum.passedCount, 23)
        XCTAssertEqual(sum.warningCount, 4)
        XCTAssertEqual(sum.failedCount, 3)
        XCTAssertEqual(sum.offlineCount, 1)

        totals1 += totals2
        XCTAssertEqual(totals1.installationCount, 8)
        XCTAssertEqual(totals1.driveCount, 30)
        XCTAssertEqual(totals1.passedCount, 23)
        XCTAssertEqual(totals1.warningCount, 4)
        XCTAssertEqual(totals1.failedCount, 3)
        XCTAssertEqual(totals1.offlineCount, 1)
    }

    func testOverviewTotalsAddEmpty() {
        var totals1 = OverviewTotals(
            installationCount: 5, driveCount: 20, passedCount: 15,
            warningCount: 3, failedCount: 2, offlineCount: 1
        )
        let empty = OverviewTotals(installations: [])

        totals1.add(empty)

        XCTAssertEqual(totals1.installationCount, 5)
        XCTAssertEqual(totals1.driveCount, 20)
        XCTAssertEqual(totals1.passedCount, 15)
        XCTAssertEqual(totals1.warningCount, 3)
        XCTAssertEqual(totals1.failedCount, 2)
        XCTAssertEqual(totals1.offlineCount, 1)
    }

    func testOverviewTotalsEmptyLeft() {
        let empty = OverviewTotals(installations: [])
        let totals2 = OverviewTotals(
            installationCount: 3, driveCount: 10, passedCount: 8,
            warningCount: 1, failedCount: 1, offlineCount: 0
        )

        let sum = empty + totals2

        XCTAssertEqual(sum.installationCount, 3)
        XCTAssertEqual(sum.driveCount, 10)
        XCTAssertEqual(sum.passedCount, 8)
        XCTAssertEqual(sum.warningCount, 1)
        XCTAssertEqual(sum.failedCount, 1)
        XCTAssertEqual(sum.offlineCount, 0)
    }
}
