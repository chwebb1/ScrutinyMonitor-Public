//
//  MetricsGrid.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//
import SwiftUI

public struct MetricsGrid: View {
    var snapshot: InstallationSnapshot

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 12, alignment: .leading)
    ]

    public var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            MetricTile(title: "Drives", value: "\(snapshot.totalDrives)", symbol: "externaldrive")
            MetricTile(title: "Passed", value: "\(snapshot.healthyDrives)", symbol: "checkmark.circle")
            MetricTile(title: "Warnings", value: "\(snapshot.warningDrives)", symbol: "exclamationmark.triangle")
            MetricTile(title: "Failed", value: "\(snapshot.criticalDrives)", symbol: "xmark.octagon")
            MetricTile(title: "Avg Temp", value: snapshot.averageTemperature.temperatureText, symbol: "thermometer.medium")
        }
    }
}
