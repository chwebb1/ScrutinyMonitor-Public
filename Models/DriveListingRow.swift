//
//  DriveListingRow.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import Foundation
struct DriveListingRow: Identifiable, Hashable {
    var id: String
    var drive: DriveSnapshot
    var values: [String]
    var cells: [DriveListingCell]

    init(id: String, drive: DriveSnapshot, values: [String]) {
        self.id = id
        self.drive = drive
        self.values = values

        var computedCells = [DriveListingCell]()
        computedCells.reserveCapacity(values.count)
        for (index, value) in values.enumerated() {
            computedCells.append(
                DriveListingCell(
                    id: "\(id)-column-\(index)",
                    index: index,
                    value: value
                )
            )
        }
        self.cells = computedCells
    }
}
