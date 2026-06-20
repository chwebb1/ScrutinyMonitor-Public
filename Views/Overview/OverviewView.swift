import SwiftUI

struct OverviewView: View {
    var installations: [ScrutinyInstallation]
    var isRefreshing: Bool
    var onRefresh: () -> Void

    @State private var drives: [OverviewDrive] = []
    @State private var totals: OverviewTotals = OverviewTotals(installations: [])

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                OverviewMetrics(totals: totals)
                OverviewDriveTable(drives: drives, isRefreshing: isRefreshing, onRefresh: onRefresh)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: installations, initial: true) { _, newInstallations in
            updateDerivedData(from: newInstallations)
        }
    }

    private func updateDerivedData(from newInstallations: [ScrutinyInstallation]) {
        let newTotals = OverviewTotals(installations: newInstallations)
        self.totals = newTotals

        var newDrives = [OverviewDrive]()

        // ⚡ Bolt: Count total drives to pre-allocate capacity from already-calculated totals
        // instead of doing an additional redundant O(N) pass via .reduce.
        newDrives.reserveCapacity(newTotals.driveCount)

        for installation in newInstallations {
            guard let devices = installation.lastSnapshot?.devices else { continue }
            for drive in devices {
                newDrives.append(OverviewDrive(installation: installation, drive: drive))
            }
        }

        newDrives.sort { (lhs: OverviewDrive, rhs: OverviewDrive) in
            if lhs.drive.status != rhs.drive.status {
                return lhs.drive.status.sortRank < rhs.drive.status.sortRank
            }

            let installationCompare = lhs.installation.name.localizedStandardCompare(rhs.installation.name)
            if installationCompare != .orderedSame {
                return installationCompare == .orderedAscending
            }

            return lhs.drive.name.localizedStandardCompare(rhs.drive.name) == .orderedAscending
        }

        self.drives = newDrives
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Overview")
                .font(.largeTitle.weight(.semibold))

            Text("All monitored drives across \(installations.count) Scrutiny installations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
