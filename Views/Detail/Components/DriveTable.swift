//
//  DriveTable.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI
public struct DriveTable: View {
    var devices: [DriveSnapshot]
    var onOpenDrive: (DriveSnapshot) -> Void

    private let columnTitles = ["Device", "Model", "Serial", "Status", "Temp", "Power On", "Capacity", ""]

    @State private var rows: [DriveListingRow] = []

    public var body: some View {
        DriveListingTable(
            title: "Drives",
            columnTitles: columnTitles,
            modelColumnIndex: 1,
            rows: rows
        ) { row in
            onOpenDrive(row.drive)
        }
        .onChange(of: devices, initial: true) { _, newDevices in
            var newRows = [DriveListingRow]()
            newRows.reserveCapacity(newDevices.count)
            for device in newDevices {
                newRows.append(
                    DriveListingRow(
                        id: device.id,
                        drive: device,
                        values: [
                            device.name,
                            device.model,
                            device.serial,
                            device.status.label,
                            device.temperatureText,
                            device.powerOnHoursText,
                            device.capacityText
                        ]
                    )
                )
            }
            rows = newRows
        }
    }
}
