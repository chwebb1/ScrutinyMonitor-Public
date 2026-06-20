//
//  OverviewRow.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI

public struct OverviewRow: View {
    var installationCount: Int
    var driveCount: Int
    var hasIssues: Bool

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hasIssues ? "rectangle.stack.badge.exclamationmark" : "rectangle.stack")
                .foregroundStyle(hasIssues ? .yellow : .secondary)
                .frame(width: 16)
                .accessibilityLabel(hasIssues ? "Issues detected" : "All clear")

            VStack(alignment: .leading, spacing: 2) {
                Text("Overview")
                    .lineLimit(1)

                Text("\(installationCount) installations - \(driveCount) drives")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Overview, \(hasIssues ? "Issues detected" : "All clear"), \(installationCount) installations, \(driveCount) drives")
    }
}
