import SwiftUI

struct ContentView: View {
    @Bindable var store: MonitorStore
    @AppStorage(AppPreferences.autoRefreshEnabledKey, store: .shared) private var autoRefreshEnabled = false
    @AppStorage(AppPreferences.autoRefreshIntervalKey, store: .shared) private var autoRefreshInterval = AppPreferences.defaultAutoRefreshInterval
    @State private var isShowingAddSheet = false
    @State private var editingInstallation: ScrutinyInstallation?
    @State private var isConfirmingDelete = false

    @MainActor var body: some View {
        NavigationSplitView {
            SidebarView(store: store) {
                isShowingAddSheet = true
            } onEditInstallation: {
                editingInstallation = store.selectedInstallation
            } onDeleteInstallation: {
                isConfirmingDelete = store.selectedInstallation != nil
            }
            .navigationTitle("Scrutiny Monitor")
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            DetailView(store: store) {
                isShowingAddSheet = true
            } onEdit: {
                editingInstallation = store.selectedInstallation
            } onDelete: {
                isConfirmingDelete = store.selectedInstallation != nil
            }
            .navigationTitle(store.selection == .overview ? "Overview" : store.selectedInstallation?.name ?? "Scrutiny Monitor")
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddInstallationView(store: store)
        }
        .sheet(item: $editingInstallation) { installation in
            AddInstallationView(store: store, editingInstallation: installation)
        }
        .confirmationDialog(
            "Delete Installation?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.removeSelectedInstallation()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .task {
            if !store.installations.isEmpty {
                do {
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                } catch {
                    return
                }
                await store.refreshAll()
            }
        }
        .task(id: autoRefreshTaskID) {
            await runAutoRefreshLoop()
        }
    }

    @MainActor private var deleteConfirmationMessage: String {
        guard let installation = store.selectedInstallation else {
            return "No installation is selected."
        }

        return "Remove \(installation.name) from Scrutiny Monitor? This does not change the Scrutiny server."
    }

    @MainActor private var autoRefreshTaskID: String {
        "\(autoRefreshEnabled)-\(autoRefreshInterval)-\(store.installations.count)"
    }

    @MainActor private func runAutoRefreshLoop() async {
        guard autoRefreshEnabled, !store.installations.isEmpty else { return }

        while !Task.isCancelled {
            let nanoseconds = UInt64(max(autoRefreshInterval, 30) * 1_000_000_000)

            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled, !store.installations.isEmpty else { return }
            await store.refreshAll()
        }
    }
}
