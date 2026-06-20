//
//  DriveSummaryGrid.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI
public struct DriveSummaryGrid: View {
    var drive: DriveSnapshot
    var detail: DriveDetail

    public var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                DetailMetric(title: "Status", value: drive.status.label, symbol: drive.status.symbolName, valueColor: drive.status.color)
                DetailMetric(title: "Protocol", value: detail.latestSmart?.deviceProtocol ?? drive.protocolName, symbol: "cable.connector")
                DetailMetric(title: "Temperature", value: detail.latestSmart?.temperature?.value.formattedTemperature ?? drive.temperatureText, symbol: "thermometer.medium")
                DetailMetric(title: "Power On", value: detail.latestSmart?.powerOnHours?.value.formattedHours ?? drive.powerOnHoursText, symbol: "clock")
                DetailMetric(title: "Power Cycles", value: detail.latestSmart?.powerCycleCount?.value.formatted() ?? "-", symbol: "power")
            }
        }
    }
}
