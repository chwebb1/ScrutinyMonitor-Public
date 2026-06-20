import Foundation

struct HealthResponse: Decodable {
    var success: Bool
    var error: String?
    var errors: [String]?
}

struct SummaryResponse: Decodable {
    var success: Bool
    var data: SummaryData?
    var error: String?
    var errors: [String]?
}

struct SummaryData: Decodable {
    var summary: [String: SummaryEntry]
}

struct SummaryEntry: Decodable {
    var device: ScrutinyDevice?
    var smart: ScrutinySmart?
}

struct ScrutinyDevice: Decodable {
    var wwn: String?
    var deviceName: String?
    var deviceUUID: String?
    var manufacturer: String?
    var modelName: String?
    var serialNumber: String?
    var firmware: String?
    var capacity: Int64?
    var rotationalSpeed: Int?
    var deviceProtocol: String?
    var deviceStatus: FlexibleInt?
    var scrutinyUUID: String?

    private enum CodingKeys: String, CodingKey {
        case wwn
        case deviceName = "device_name"
        case deviceUUID = "device_uuid"
        case manufacturer
        case modelName = "model_name"
        case serialNumber = "serial_number"
        case firmware
        case capacity
        case rotationalSpeed = "rotational_speed"
        case deviceProtocol = "device_protocol"
        case deviceStatus = "device_status"
        case scrutinyUUID = "scrutiny_uuid"
    }
}

struct ScrutinySmart: Decodable {
    var collectorDate: String?
    var temp: FlexibleInt?
    var powerOnHours: FlexibleInt?

    private enum CodingKeys: String, CodingKey {
        case collectorDate = "collector_date"
        case temp
        case powerOnHours = "power_on_hours"
    }
}

struct FlexibleInt: Decodable, Hashable {
    var value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        do {
            value = try container.decode(Int.self)
            return
        } catch DecodingError.typeMismatch(_, _), DecodingError.dataCorrupted(_) { }

        do {
            let double = try container.decode(Double.self)
            value = Int(double)
            return
        } catch DecodingError.typeMismatch(_, _), DecodingError.dataCorrupted(_) { }

        do {
            let string = try container.decode(String.self)
            if let converted = Int(string) {
                value = converted
                return
            }
        } catch DecodingError.typeMismatch(_, _), DecodingError.dataCorrupted(_) { }

        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected an integer-compatible value.")
        )
    }
}
