//
//  OverviewMetrics.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI

@MainActor public struct OverviewMetrics: View {
    var totals: OverviewTotals

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 12, alignment: .leading)
    ]

    public var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            MetricTile(title: "Installations", value: "\(totals.installationCount)", symbol: "server.rack")
            MetricTile(title: "Drives", value: "\(totals.driveCount)", symbol: "externaldrive")
            MetricTile(title: "Passed", value: "\(totals.passedCount)", symbol: "checkmark.circle")
            MetricTile(title: "Warnings", value: "\(totals.warningCount)", symbol: "exclamationmark.triangle")
            MetricTile(title: "Failed", value: "\(totals.failedCount)", symbol: "xmark.octagon")
            MetricTile(title: "Offline", value: "\(totals.offlineCount)", symbol: "wifi.slash")
        }
    }
}

