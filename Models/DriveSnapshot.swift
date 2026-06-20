
//
//  DriveSnapshot.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import Foundation
import os

struct DriveSnapshot: Identifiable, Codable, Hashable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScrutinyMonitor", category: "DriveSnapshot")
    
    let id: String
    let name: String
    let model: String
    let serial: String
    let protocolName: String
    let capacityBytes: Int64?
    let statusCode: Int?
    let temperature: Int?
    let powerOnHours: Int?
    let collectorDate: String?

    // ⚡ Bolt: Derived formatting properties are pre-calculated to avoid repetitive
    // string allocations during SwiftUI Table/List rendering loops.
    let status: DriveStatus
    let temperatureText: String
    let powerOnHoursText: String
    let capacityText: String

    enum CodingKeys: String, CodingKey {
        case id, name, model, serial, protocolName, capacityBytes, statusCode, temperature, powerOnHours, collectorDate
    }

    // Physically plausible temperature range for storage devices (Celsius)
    // -40°C: Minimum operational temperature for industrial storage devices
    // 120°C: Maximum absolute limit before catastrophic failure
    static let minPlausibleTemperature: Int = -40
    static let maxPlausibleTemperature: Int = 120

    private static func validateTemperature(_ value: Int) -> Int? {
        if value < minPlausibleTemperature || value > maxPlausibleTemperature {
            return nil
        }
        return value
    }

    init(id: String, name: String, model: String, serial: String, protocolName: String, capacityBytes: Int64?, statusCode: Int?, temperature: Int?, powerOnHours: Int?, collectorDate: String?) {
        self.id = id
        self.name = name
        self.model = model
        self.serial = serial
        self.protocolName = protocolName
        if let cap = capacityBytes {
            if cap < 0 || cap > 100_000_000_000_000_000 {
                Self.logger.warning("Discarding implausible capacityBytes: \(cap)")
                self.capacityBytes = nil
            } else {
                self.capacityBytes = cap
            }
        } else {
            self.capacityBytes = nil
        }
        self.statusCode = statusCode
        if let temp = temperature {
            let valid = Self.validateTemperature(temp)
            if valid == nil {
                Self.logger.warning("Discarding implausible temperature: \(temp)°C (outside \(Self.minPlausibleTemperature)...\(Self.maxPlausibleTemperature)°C)")
            }
            self.temperature = valid
        } else {
            self.temperature = nil
        }
        if let hours = powerOnHours {
            if hours < 0 || hours > 1_000_000 {
                Self.logger.warning("Discarding implausible powerOnHours: \(hours)")
                self.powerOnHours = nil
            } else {
                self.powerOnHours = hours
            }
        } else {
            self.powerOnHours = nil
        }
        self.collectorDate = collectorDate

        self.status = DriveStatus(statusCode: statusCode)
        self.temperatureText = self.temperature.temperatureText
        self.powerOnHoursText = self.powerOnHours.hoursText
        self.capacityText = self.capacityBytes.formattedBytes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let model = try container.decode(String.self, forKey: .model)
        let serial = try container.decode(String.self, forKey: .serial)
        let protocolName = try container.decode(String.self, forKey: .protocolName)
        let capacityBytes = try container.decodeIfPresent(Int64.self, forKey: .capacityBytes)
        let statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
        let temperature = try container.decodeIfPresent(Int.self, forKey: .temperature)
        let powerOnHours = try container.decodeIfPresent(Int.self, forKey: .powerOnHours)
        let collectorDate = try container.decodeIfPresent(String.self, forKey: .collectorDate)

        self.init(id: id, name: name, model: model, serial: serial, protocolName: protocolName, capacityBytes: capacityBytes, statusCode: statusCode, temperature: temperature, powerOnHours: powerOnHours, collectorDate: collectorDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(model, forKey: .model)
        try container.encode(serial, forKey: .serial)
        try container.encode(protocolName, forKey: .protocolName)
        try container.encodeIfPresent(capacityBytes, forKey: .capacityBytes)
        try container.encodeIfPresent(statusCode, forKey: .statusCode)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(powerOnHours, forKey: .powerOnHours)
        try container.encodeIfPresent(collectorDate, forKey: .collectorDate)
    }
}

