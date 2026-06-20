import SwiftUI

struct MenuBarView: View {
    let store: MonitorStore

    @State private var isLoaded = NSClassFromString("XCTest") != nil

    var body: some View {
        VStack(spacing: 0) {
            if isLoaded {
                // Header
                headerView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.windowBackgroundColor))
                
                Divider()

                // Scrollable Content
                if store.installations.isEmpty {
                    emptyStateView
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(store.installations) { installation in
                                installationCard(for: installation)
                            }
                        }
                        .padding(16)
                    }
                }

                Divider()

                // Footer
                footerView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.windowBackgroundColor))
            } else {
                Color.clear
                    .frame(width: 360, height: 480)
                    .onAppear {
                        DispatchQueue.main.async {
                            isLoaded = true
                        }
                    }
            }
        }
        .frame(width: 360, height: 480)
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Scrutiny Monitor")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
                    .accessibilityLabel("Refreshing")
                    .help("Refreshing...")
            } else {
                Button {
                    Task {
                        await store.refreshAll()
                    }
                } label: {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh All")
                .help("Refresh All (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }

            Button {
                openMainWindow()
            } label: {
                Label("Open Main App", systemImage: "macwindow.on.rectangle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Main App")
            .help("Open Main App")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text("No Installations Configured")
                .font(.headline)
            
            Text("Add an installation in the main app to start monitoring your hard drives.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Open Main App") {
                openMainWindow()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func installationCard(for installation: ScrutinyInstallation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Installation Info
            Button {
                StatusBarController.shared.openInstallation(installation)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(installation.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(installation.hostText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: installation.status.symbolName)
                        .foregroundColor(installation.status.color)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(installation.name), Status: \(installation.status.label), \(installation.hostText)")
            }
            .buttonStyle(.plain)
            .help("Open \(installation.name)")
            .padding(.bottom, 4)

            // Drives/Status
            if installation.isRefreshing {
                HStack {
                    Spacer()
                    ProgressView("Refreshing...")
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing")
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let error = installation.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Error: \(error)")
                .padding(.vertical, 4)
            } else if let snapshot = installation.lastSnapshot {
                if snapshot.devices.isEmpty {
                    Text("No drives detected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(snapshot.devices) { device in
                            driveRow(for: device, installation: installation)
                        }
                    }
                }
            } else {
                Text("Never refreshed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func driveRow(for device: DriveSnapshot, installation: ScrutinyInstallation) -> some View {
        Button {
            StatusBarController.shared.openDriveDetails(installation: installation, drive: device)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: device.status.symbolName)
                    .foregroundColor(device.status.color)
                    .accessibilityHidden(true)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(device.model)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let temp = device.temperature {
                        Text("\(temp)°C")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(tempColor(temp).opacity(0.15))
                            .foregroundColor(tempColor(temp))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if device.powerOnHours != nil {
                        Text(device.powerOnHoursText)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(device.name), \(device.model), Status: \(device.status.label), Temperature: \(device.temperatureText), Power On: \(device.powerOnHoursText)")
        }
        .buttonStyle(.plain)
        .help("Show SMART details for \(device.name)")
        .padding(.vertical, 2)
    }

    private var footerView: some View {
        HStack {
            Button("Settings...") {
                StatusBarController.shared.openSettings()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .keyboardShortcut(",", modifiers: .command)
            .help("Open Settings (⌘,)")
            
            Spacer()
            
            TimelineView(.periodic(from: .now, by: 10)) { timelineContext in
                if let lastSync = lastSyncDateString(at: timelineContext.date) {
                    Text("Updated approximately \(lastSync)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit (⌘Q)")
        }
    }

    // MARK: - Helper Methods

    private func tempColor(_ temp: Int) -> Color {
        if temp >= 45 {
            return .red
        } else if temp >= 35 {
            return .orange
        } else {
            return .green
        }
    }

    private func lastSyncDateString(at now: Date) -> String? {
        guard let maxDate = store.lastRefreshDate else { return nil }
        
        // ⚡ Bolt: Use a statically cached RelativeDateTimeFormatter to avoid expensive instantiation
        // overhead on every view render tick or update loop.
        return AppFormatters.relativeDateFull.localizedString(for: maxDate, relativeTo: now)
    }

    private func openMainWindow() {
        StatusBarController.shared.openMainWindow()
    }
}
