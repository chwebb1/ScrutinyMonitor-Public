//
//  OverviewDriveTable.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI
public struct OverviewDriveTable: View {
    var drives: [OverviewDrive]
    var isRefreshing: Bool
    var onRefresh: () -> Void
    @State private var selectedDrive: OverviewDrive?

    private let columnTitles = ["Installation", "Drive", "Model", "Status", "Temp", "Power On", "Capacity", ""]

    @State private var rows: [DriveListingRow] = []

    public var body: some View {
        Group {
            if drives.isEmpty {
                if isRefreshing {
                    ContentUnavailableView {
                        Label("Loading...", systemImage: "arrow.clockwise")
                    } description: {
                        ProgressView()
                            .accessibilityLabel("Loading")
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    ContentUnavailableView {
                        Label("No Drive Data", systemImage: "externaldrive.badge.questionmark")
                    } description: {
                        Text("Refresh your installations to load drive status.")
                    } actions: {
                        Button("Refresh") {
                            onRefresh()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                }
            } else {
                DriveListingTable(
                    title: "All Drives",
                    columnTitles: columnTitles,
                    modelColumnIndex: 2,
                    rows: rows
                ) { row in
                    selectedDrive = drives.first { $0.id == row.id }
                }
            }
        }
        .sheet(item: $selectedDrive) { overviewDrive in
            DriveDetailView(installation: overviewDrive.installation, drive: overviewDrive.drive)
        }
        .onChange(of: drives, initial: true) { _, newDrives in
            var newRows = [DriveListingRow]()
            newRows.reserveCapacity(newDrives.count)
            for overviewDrive in newDrives {
                newRows.append(
                    DriveListingRow(
                        id: overviewDrive.id,
                        drive: overviewDrive.drive,
                        values: [
                            overviewDrive.installation.name,
                            overviewDrive.drive.name,
                            overviewDrive.drive.model,
                            overviewDrive.drive.status.label,
                            overviewDrive.drive.temperatureText,
                            overviewDrive.drive.powerOnHoursText,
                            overviewDrive.drive.capacityText
                        ]
                    )
                )
            }
            rows = newRows
        }
    }
}
