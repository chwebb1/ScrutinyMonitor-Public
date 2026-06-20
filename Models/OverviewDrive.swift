//
//  OverviewDrive.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//


public struct OverviewDrive: Identifiable, Hashable {
    var installation: ScrutinyInstallation
    var drive: DriveSnapshot

    public var id: String {
        "\(installation.id.uuidString)-\(drive.id)"
    }
}
