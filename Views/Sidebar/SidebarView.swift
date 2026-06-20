import SwiftUI

struct SidebarView: View {
    @Bindable var store: MonitorStore
    var onAddInstallation: () -> Void
    var onEditInstallation: () -> Void
    var onDeleteInstallation: () -> Void

    var body: some View {
        List(selection: $store.selection) {
            if store.installations.count > 1 {
                OverviewRow(
                    installationCount: store.installations.count,
                    driveCount: store.overviewDriveCount,
                    hasIssues: store.overviewHasIssues
                )
                .tag(MonitorSelection.overview)
            }

            if !store.installations.isEmpty {
                Section("Installations") {
                    ForEach(store.installations) { installation in
                        InstallationRow(installation: installation)
                            .tag(MonitorSelection.installation(installation.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if store.installations.isEmpty {
                ContentUnavailableView {
                    Label("No Installations", systemImage: "externaldrive.badge.plus")
                } description: {
                    Text("Add a Scrutiny server to begin monitoring NAS drive health.")
                } actions: {
                    Button("Add Installation") {
                        onAddInstallation()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarActionBar(
                selectedInstallationName: store.selectedInstallation?.name,
                onAddInstallation: onAddInstallation,
                onEditInstallation: onEditInstallation,
                onDeleteInstallation: onDeleteInstallation
            )
        }
    }
}





