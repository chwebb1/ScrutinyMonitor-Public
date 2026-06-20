//
//  to.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI

public struct InstallationRow: View {
    var installation: ScrutinyInstallation

    public var body: some View {
        HStack(spacing: 10) {
            Group {
                if installation.status == .refreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing")
                } else {
                    Image(systemName: installation.status.symbolName)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(installation.status.color)
            .frame(width: 16)
            .accessibilityLabel(installation.status.label)

            VStack(alignment: .leading, spacing: 2) {
                Text(installation.name)
                    .lineLimit(1)

                Text(rowDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let snapshot = installation.lastSnapshot {
            return "\(installation.name), Status: \(installation.status.label), \(snapshot.totalDrives) drives"
        }

        if installation.lastError != nil {
            return "\(installation.name), Status: Offline"
        }

        return "\(installation.name), Status: \(installation.status.label), \(installation.hostText)"
    }

    private var rowDetail: String {
        if let snapshot = installation.lastSnapshot {
            return "\(installation.status.label) - \(snapshot.totalDrives) drives"
        }

        if installation.lastError != nil {
            return "Offline"
        }

        return installation.hostText
    }
}
