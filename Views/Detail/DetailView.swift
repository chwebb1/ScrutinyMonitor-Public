import AppKit
import SwiftUI

struct DetailView: View {
    @Bindable var store: MonitorStore
    var onAdd: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @MainActor private var isRefreshing: Bool {
        if store.selection == .overview {
            return store.isRefreshing
        } else {
            return store.selectedInstallation?.isRefreshing ?? false
        }
    }

    @MainActor private var refreshHelpText: String {
        if store.installations.isEmpty {
            return "No installations to refresh"
        } else if isRefreshing {
            return "Refreshing..."
        } else if store.selection == .overview {
            return "Refresh all installations"
        } else {
            return "Refresh selected installation"
        }
    }

    var body: some View {
        Group {
            if store.installations.count > 1, store.selection == .overview {
                OverviewView(installations: store.installations, isRefreshing: store.isRefreshing) {
                    Task { await store.refreshAll() }
                }
            } else if let installation = store.selectedInstallation {
                InstallationDetail(installation: installation, onEdit: onEdit, onDelete: onDelete) {
                    Task { await store.refreshSelected() }
                }
            } else {
                if store.installations.isEmpty {
                    ContentUnavailableView {
                        Label("No Installations", systemImage: "externaldrive.badge.plus")
                    } description: {
                        Text("Add a Scrutiny server from the sidebar to begin monitoring.")
                    } actions: {
                        Button("Add Installation") {
                            onAdd()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView(
                        "Select an Installation",
                        systemImage: "server.rack",
                        description: Text("Choose a Scrutiny server from the sidebar.")
                    )
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        if store.selection == .overview {
                            await store.refreshAll()
                        } else {
                            await store.refreshSelected()
                        }
                    }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing")
                            .help("Refreshing...")
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }
                }
                .accessibilityLabel("Refresh")
                .help("\(refreshHelpText) (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.installations.isEmpty || isRefreshing)

                if let installation = store.selectedInstallation {
                    Button {
                        NSWorkspace.shared.open(installation.baseURL)
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Open \(installation.name) in Browser")
                    .help("Open \(installation.name) in Browser (⌘O)")
                    .keyboardShortcut("o", modifiers: .command)

                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Edit \(installation.name)")
                    .help("Edit \(installation.name) (⌘E)")
                    .keyboardShortcut("e", modifiers: .command)

                    Button(role: .destructive, action: onDelete) {
                        Label("Remove", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Remove \(installation.name)")
                    .help("Remove \(installation.name) (⌘⌫)")
                    .keyboardShortcut(.delete, modifiers: .command)
                }
            }
        }
    }
}










