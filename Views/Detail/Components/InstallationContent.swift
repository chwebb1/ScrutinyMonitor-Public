//
//  InstallationContent.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI

public struct InstallationContent: View {
    var installation: ScrutinyInstallation
    @Binding var selectedDrive: DriveSnapshot?
    var onRefresh: () -> Void

    public var body: some View {
        if let error = installation.lastError {
            ErrorPanel(message: error)
        }

        if let snapshot = installation.lastSnapshot {
            MetricsGrid(snapshot: snapshot)
            DriveTable(devices: snapshot.devices) { drive in
                selectedDrive = drive
            }
        } else if installation.lastError != nil {
            ContentUnavailableView {
                Label("Could Not Load Data", systemImage: "exclamationmark.triangle")
            } description: {
                Text("An error occurred while fetching drive health.")
            } actions: {
                Button("Try Again") {
                    onRefresh()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        } else if installation.lastError == nil {
            if installation.isRefreshing {
                ContentUnavailableView {
                    Label("Loading...", systemImage: "arrow.clockwise")
                } description: {
                    ProgressView()
                        .accessibilityLabel("Loading")
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                ContentUnavailableView {
                    Label("Not Refreshed", systemImage: "arrow.clockwise")
                } description: {
                    Text("Refresh this installation to load drive health.")
                } actions: {
                    Button("Refresh") {
                        onRefresh()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            }
        }
    }
}
