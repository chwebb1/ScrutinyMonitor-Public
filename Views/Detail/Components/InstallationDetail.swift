//
//  InstallationDetail.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI

public struct InstallationDetail: View {
    var installation: ScrutinyInstallation
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onRefresh: () -> Void
    @State private var selectedDrive: DriveSnapshot?

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                InstallationContent(installation: installation, selectedDrive: $selectedDrive, onRefresh: onRefresh)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $selectedDrive) { drive in
            DriveDetailView(installation: installation, drive: drive)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(installation.name)
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Group {
                    if installation.status == .refreshing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel(installation.status.label)
                            Text(installation.status.label)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Status: \(installation.status.label)")
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: installation.status.symbolName)
                                .accessibilityHidden(true)
                            Text(installation.status.label)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Status: \(installation.status.label)")
                    }
                }
                .font(.headline)
                .foregroundStyle(installation.status.color)
            }

            HStack(spacing: 12) {
                Text(installation.baseURL.absoluteString)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if let lastRefreshDate = installation.lastRefreshDate {
                    RelativeDateView(lastRefreshDate: lastRefreshDate)
                }
            }
            .font(.subheadline)
        }
    }
}
