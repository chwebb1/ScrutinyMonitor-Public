import Foundation

extension ScrutinyInstallation {
    static var previewInstallations: [ScrutinyInstallation] {
        let uuid1 = UUID()
        let uuid2 = UUID()
        let dev1 = DriveSnapshot(id: "1", name: "sda", model: "WD Red 4TB", serial: "WD-1", protocolName: "SATA", capacityBytes: 4000000000000, statusCode: 0, temperature: 31, powerOnHours: 12000, collectorDate: nil)
        let dev2 = DriveSnapshot(id: "2", name: "sdb", model: "WD Red 4TB", serial: "WD-2", protocolName: "SATA", capacityBytes: 4000000000000, statusCode: 0, temperature: 33, powerOnHours: 12000, collectorDate: nil)
        let dev3 = DriveSnapshot(id: "3", name: "sdc", model: "IronWolf 8TB", serial: "ST-3", protocolName: "SATA", capacityBytes: 8000000000000, statusCode: 4, temperature: 42, powerOnHours: 8500, collectorDate: nil)

        let snap1 = InstallationSnapshot(healthOK: true, totalDrives: 2, healthyDrives: 2, warningDrives: 0, criticalDrives: 0, devices: [dev1, dev2], collectedAt: Date())
        let snap2 = InstallationSnapshot(healthOK: false, totalDrives: 1, healthyDrives: 0, warningDrives: 1, criticalDrives: 0, devices: [dev3], collectedAt: Date())

        return [
            ScrutinyInstallation(id: uuid1, name: "Home NAS", baseURL: URL(string: "http://192.168.1.100")!, lastSnapshot: snap1),
            ScrutinyInstallation(id: uuid2, name: "Backup Server", baseURL: URL(string: "http://192.168.1.200")!, lastSnapshot: snap2)
        ]
    }
}
