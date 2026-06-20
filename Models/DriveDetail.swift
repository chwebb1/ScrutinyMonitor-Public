import Foundation
import SwiftUI

struct DriveDetail: Identifiable {
    let id: String
    let device: ScrutinyDevice?
    let latestSmart: SmartResult?
    let history: [SmartResult]
    let metadata: [String: SmartAttributeMetadata]
    let attributes: [SmartAttributeRow]

    init(id: String, device: ScrutinyDevice?, history: [SmartResult], metadata: [String: SmartAttributeMetadata]) {
        self.id = id
        self.device = device
        
        let sortedHistory = history.sorted { lhs, rhs in
            guard let lDate = lhs.parsedDate else { return false }
            guard let rDate = rhs.parsedDate else { return true }
            return lDate < rDate
        }
        self.history = sortedHistory
        self.latestSmart = sortedHistory.last
        self.metadata = metadata

        guard let latestSmart = sortedHistory.last else {
            self.attributes = []
            return
        }

        var result = [SmartAttributeRow]()
        result.reserveCapacity(latestSmart.attributes.count)

        for (key, attribute) in latestSmart.attributes {
            let normalizedKey: String
            let rowMetadata: SmartAttributeMetadata?

            if let attrID = attribute.attributeID {
                if key == attrID {
                    normalizedKey = key
                    rowMetadata = metadata[key]
                } else {
                    normalizedKey = attrID
                    rowMetadata = metadata[normalizedKey] ?? metadata[key]
                }
            } else {
                normalizedKey = key
                rowMetadata = metadata[key]
            }

            result.append(SmartAttributeRow(id: normalizedKey, attribute: attribute, metadata: rowMetadata))
        }

        result.sort { lhs, rhs in
            if let lhsID = Int(lhs.id), let rhsID = Int(rhs.id) {
                return lhsID < rhsID
            }

            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }

        self.attributes = result
    }
}

struct SmartResult: Decodable, Hashable {
    var date: String?
    var scrutinyUUID: String?
    var deviceProtocol: String?
    var temperature: FlexibleInt?
    var powerOnHours: FlexibleInt?
    var powerCycleCount: FlexibleInt?
    var attributes: [String: SmartAttributeDetail]
    // ⚡ Bolt: Pre-calculated to avoid expensive O(N) DateFormatter calls in SwiftUI render loops
    var parsedDate: Date?

    private enum CodingKeys: String, CodingKey {
        case date
        case scrutinyUUID = "scrutiny_uuid"
        case deviceProtocol = "device_protocol"
        case temperature = "temp"
        case powerOnHours = "power_on_hours"
        case powerCycleCount = "power_cycle_count"
        case attributes = "attrs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        scrutinyUUID = try container.decodeIfPresent(String.self, forKey: .scrutinyUUID)
        deviceProtocol = try container.decodeIfPresent(String.self, forKey: .deviceProtocol)
        temperature = try container.decodeIfPresent(FlexibleInt.self, forKey: .temperature)
        powerOnHours = try container.decodeIfPresent(FlexibleInt.self, forKey: .powerOnHours)
        powerCycleCount = try container.decodeIfPresent(FlexibleInt.self, forKey: .powerCycleCount)

        do {
            attributes = try container.decodeIfPresent([String: SmartAttributeDetail].self, forKey: .attributes) ?? [:]
        } catch {
            if let _ = try? container.decodeIfPresent([SmartAttributeDetail].self, forKey: .attributes) {
                attributes = [:]
            } else if let _ = try? container.decodeIfPresent([String].self, forKey: .attributes) {
                attributes = [:]
            } else {
                throw error
            }
        }

        if let date = date {
            if let parsed = Self.fractionalFormatter.date(from: date) {
                parsedDate = parsed
            } else {
                parsedDate = Self.standardFormatter.date(from: date)
            }
        }
    }
}

extension SmartResult {
    fileprivate static let fractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    fileprivate static let standardFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

}

struct SmartAttributeDetail: Decodable, Hashable {
    var attributeID: String?
    var value: Int?
    var threshold: Int?
    var worst: Int?
    var rawValue: Int?
    var rawString: String?
    var transformedValue: Int?
    var status: Int?
    var statusReason: String?
    var failureRate: Double?
    var whenFailed: String?

    private enum CodingKeys: String, CodingKey {
        case attributeID = "attribute_id"
        case value
        case threshold = "thresh"
        case worst
        case rawValue = "raw_value"
        case rawString = "raw_string"
        case transformedValue = "transformed_value"
        case status
        case statusReason = "status_reason"
        case failureRate = "failure_rate"
        case whenFailed = "when_failed"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .attributeID) {
            attributeID = String(intId)
        } else {
            attributeID = try container.decodeIfPresent(String.self, forKey: .attributeID)
        }
        value = try container.decodeFlexibleIfPresent(Int.self, forKey: .value)
        threshold = try container.decodeFlexibleIfPresent(Int.self, forKey: .threshold)
        worst = try container.decodeFlexibleIfPresent(Int.self, forKey: .worst)
        rawValue = try container.decodeFlexibleIfPresent(Int.self, forKey: .rawValue)
        rawString = try container.decodeIfPresent(String.self, forKey: .rawString)
        transformedValue = try container.decodeFlexibleIfPresent(Int.self, forKey: .transformedValue)
        status = try container.decodeFlexibleIfPresent(Int.self, forKey: .status)
        statusReason = try container.decodeIfPresent(String.self, forKey: .statusReason)
        failureRate = try container.decodeFlexibleIfPresent(Double.self, forKey: .failureRate)
        whenFailed = try container.decodeIfPresent(String.self, forKey: .whenFailed)
    }
}

struct SmartAttributeMetadata: Decodable, Hashable {
    var displayName: String?
    var ideal: String?
    var critical: Bool?
    var description: String?
    var displayType: String?
    var transformValueUnit: String?

    private enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case ideal
        case critical
        case description
        case displayType = "display_type"
        case transformValueUnit = "transform_value_unit"
    }
}

// ⚡ Bolt: Pre-calculate expensive string manipulation and severity mapping
// into stored properties instead of computed properties.
// SwiftUI Table renders access these values repeatedly during view updates,
// leading to unnecessary string allocations and redundant switch/bitmask operations.
struct SmartAttributeRow: Identifiable, Hashable {
    let id: String
    let attribute: SmartAttributeDetail
    let metadata: SmartAttributeMetadata?

    let name: String
    let rawText: String
    let valueText: String
    let worstText: String
    let thresholdText: String
    let shouldShowIdentifier: Bool
    let statusText: String
    let statusDetailText: String
    let severity: SmartAttributeSeverity

    init(id: String, attribute: SmartAttributeDetail, metadata: SmartAttributeMetadata?) {
        self.id = id
        self.attribute = attribute
        self.metadata = metadata

        let resolvedName = metadata?.displayName ?? "Attribute \(id)"
        self.name = resolvedName

        if let rawString = attribute.rawString, !rawString.isEmpty {
            self.rawText = rawString
        } else if let rawValue = attribute.rawValue {
            self.rawText = String(rawValue)
        } else {
            self.rawText = "-"
        }

        if let transformed = attribute.transformedValue {
            self.valueText = String(transformed)
        } else if let val = attribute.value {
            self.valueText = String(val)
        } else {
            self.valueText = "-"
        }

        self.worstText = attribute.worst.map(String.init) ?? "-"
        self.thresholdText = attribute.threshold.map(String.init) ?? "-"

        let normalizedName = resolvedName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        self.shouldShowIdentifier = !id.isEmpty && normalizedName != id.lowercased()

        let resolvedSeverity = SmartAttributeSeverity(status: attribute.status)
        self.severity = resolvedSeverity

        let resolvedStatusText: String
        if let whenFailed = attribute.whenFailed, !whenFailed.isEmpty {
            resolvedStatusText = whenFailed
        } else {
            switch resolvedSeverity {
            case .failed:
                resolvedStatusText = "Failed"
            case .warning:
                resolvedStatusText = "Warning"
            case .passed:
                resolvedStatusText = "OK"
            }
        }
        self.statusText = resolvedStatusText

        if let statusReason = attribute.statusReason, !statusReason.isEmpty {
            self.statusDetailText = statusReason
        } else {
            self.statusDetailText = resolvedStatusText
        }
    }
}

enum SmartAttributeSeverity: Hashable {
    case passed
    case warning
    case failed

    init(status: Int?) {
        guard let status = status else {
            self = .passed
            return
        }

        if status & 0b001 != 0 || status & 0b100 != 0 {
            self = .failed
        } else if status & 0b010 != 0 {
            self = .warning
        } else {
            self = .passed
		}
	}
    var color: Color {
        switch self {
        case .passed:
            .secondary
        case .warning:
            .yellow
        case .failed:
            .red
        }
    }
}

struct DriveDetailResponse: Decodable {
    var success: Bool
    var data: DriveDetailData?
    var metadata: [String: SmartAttributeMetadata]?
    var error: String?
    var errors: [String]?

    private enum CodingKeys: String, CodingKey {
        case success, data, metadata, error, errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        data = try container.decodeIfPresent(DriveDetailData.self, forKey: .data)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        errors = try container.decodeIfPresent([String].self, forKey: .errors)

        do {
            metadata = try container.decodeIfPresent([String: SmartAttributeMetadata].self, forKey: .metadata)
        } catch {
            if let _ = try? container.decodeIfPresent([String].self, forKey: .metadata) {
                metadata = [:]
            } else {
                throw error
            }
        }
    }
}

struct DriveDetailData: Decodable {
    var device: ScrutinyDevice?
    var smartResults: [SmartResult]

    private enum CodingKeys: String, CodingKey {
        case device
        case smartResults = "smart_results"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device = try container.decodeIfPresent(ScrutinyDevice.self, forKey: .device)
        smartResults = try container.decodeIfPresent([SmartResult].self, forKey: .smartResults) ?? []
    }
}

private protocol FlexibleDecodable: Decodable, LosslessStringConvertible {
    init(_ int: Int)
    init(_ double: Double)
}

extension Int: FlexibleDecodable {}
extension Double: FlexibleDecodable {}

private extension KeyedDecodingContainer {
    func decodeFlexibleIfPresent<T: FlexibleDecodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }

        do {
            return try decode(T.self, forKey: key)
        } catch let originalError {
            // 1. Attempt type coercion for numeric mismatch
            if T.self == Int.self, let double = try? decode(Double.self, forKey: key) {
                return T(double)
            } else if T.self == Double.self, let int = try? decode(Int.self, forKey: key) {
                return T(int)
            }

            // 2. Attempt string conversion fallback
            if let string = try? decode(String.self, forKey: key) {
                if let converted = T(string) {
                    return converted
                } else {
                    throw DecodingError.dataCorruptedError(
                        forKey: key,
                        in: self,
                        debugDescription: "Could not convert string '\(string)' to \(T.self)"
                    )
                }
            }

            // 3. Rethrow the original mismatch error for better diagnostics
            throw originalError
        }
    }
}
