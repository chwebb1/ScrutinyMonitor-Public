import XCTest
@testable import ScrutinyMonitor

final class DriveSnapshotTests: XCTestCase {

    func testEncodeDriveSnapshot() throws {
        let snapshot = DriveSnapshot(
            id: "drive-1",
            name: "TestDrive",
            model: "TestModel",
            serial: "12345",
            protocolName: "NVMe",
            capacityBytes: 1024,
            statusCode: 2,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-01-01T00:00:00Z"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)

        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(json)

        XCTAssertEqual(json?["id"] as? String, "drive-1")
        XCTAssertEqual(json?["name"] as? String, "TestDrive")
        XCTAssertEqual(json?["model"] as? String, "TestModel")
        XCTAssertEqual(json?["serial"] as? String, "12345")
        XCTAssertEqual(json?["protocolName"] as? String, "NVMe")
        XCTAssertEqual(json?["capacityBytes"] as? Int, 1024)
        XCTAssertEqual(json?["statusCode"] as? Int, 2)
        XCTAssertEqual(json?["temperature"] as? Int, 35)
        XCTAssertEqual(json?["powerOnHours"] as? Int, 100)
        XCTAssertEqual(json?["collectorDate"] as? String, "2023-01-01T00:00:00Z")

        XCTAssertNil(json?["status"])
        XCTAssertNil(json?["temperatureText"])
        XCTAssertNil(json?["powerOnHoursText"])
        XCTAssertNil(json?["capacityText"])
    }

    func testEncodeDriveSnapshotWithNils() throws {
        let snapshot = DriveSnapshot(
            id: "drive-2",
            name: "TestDrive2",
            model: "TestModel2",
            serial: "54321",
            protocolName: "SATA",
            capacityBytes: nil,
            statusCode: nil,
            temperature: nil,
            powerOnHours: nil,
            collectorDate: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)

        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(json)

        XCTAssertEqual(json?["id"] as? String, "drive-2")
        XCTAssertEqual(json?["name"] as? String, "TestDrive2")
        XCTAssertEqual(json?["model"] as? String, "TestModel2")
        XCTAssertEqual(json?["serial"] as? String, "54321")
        XCTAssertEqual(json?["protocolName"] as? String, "SATA")

        XCTAssertNil(json?["capacityBytes"])
        XCTAssertNil(json?["statusCode"])
        XCTAssertNil(json?["temperature"])
        XCTAssertNil(json?["powerOnHours"])
        XCTAssertNil(json?["collectorDate"])
    }

    func testRoundTripEncodeDecode() throws {
        let original = DriveSnapshot(
            id: "drive-3",
            name: "TestDrive3",
            model: "TestModel3",
            serial: "67890",
            protocolName: "SCSI",
            capacityBytes: 2048,
            statusCode: 1,
            temperature: 40,
            powerOnHours: 200,
            collectorDate: "2023-01-02T00:00:00Z"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DriveSnapshot.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.model, decoded.model)
        XCTAssertEqual(original.serial, decoded.serial)
        XCTAssertEqual(original.protocolName, decoded.protocolName)
        XCTAssertEqual(original.capacityBytes, decoded.capacityBytes)
        XCTAssertEqual(original.statusCode, decoded.statusCode)
        XCTAssertEqual(original.temperature, decoded.temperature)
        XCTAssertEqual(original.powerOnHours, decoded.powerOnHours)
        XCTAssertEqual(original.collectorDate, decoded.collectorDate)
    }
    
    func testMemberwiseInitializer() {
        let snapshot = DriveSnapshot(
            id: "drive-1",
            name: "My Drive",
            model: "Samsung SSD 980",
            serial: "S123456789",
            protocolName: "NVMe",
            capacityBytes: 1_000_000_000,
            statusCode: 0,
            temperature: 42,
            powerOnHours: 100,
            collectorDate: "2023-10-27T10:00:00Z"
        )

        XCTAssertEqual(snapshot.id, "drive-1")
        XCTAssertEqual(snapshot.name, "My Drive")
        XCTAssertEqual(snapshot.model, "Samsung SSD 980")
        XCTAssertEqual(snapshot.serial, "S123456789")
        XCTAssertEqual(snapshot.protocolName, "NVMe")
        XCTAssertEqual(snapshot.capacityBytes, 1_000_000_000)
        XCTAssertEqual(snapshot.statusCode, 0)
        XCTAssertEqual(snapshot.temperature, 42)
        XCTAssertEqual(snapshot.powerOnHours, 100)
        XCTAssertEqual(snapshot.collectorDate, "2023-10-27T10:00:00Z")

        // Derived properties
        XCTAssertEqual(snapshot.status, DriveStatus(statusCode: 0))
        XCTAssertEqual(snapshot.temperatureText, "42 C")
        XCTAssertEqual(snapshot.powerOnHoursText, "100 h")
        XCTAssertEqual(snapshot.capacityText, "1 GB")
    }

    func testDecodeWithAllFields() throws {
        let jsonString = """
        {
            "id": "drive-2",
            "name": "External HDD",
            "model": "WD My Passport",
            "serial": "WX12345",
            "protocolName": "USB",
            "capacityBytes": 2000000000,
            "statusCode": 1,
            "temperature": 35,
            "powerOnHours": 500,
            "collectorDate": "2023-10-28T12:00:00Z"
        }
        """

        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(DriveSnapshot.self, from: jsonData)

        XCTAssertEqual(snapshot.id, "drive-2")
        XCTAssertEqual(snapshot.name, "External HDD")
        XCTAssertEqual(snapshot.model, "WD My Passport")
        XCTAssertEqual(snapshot.serial, "WX12345")
        XCTAssertEqual(snapshot.protocolName, "USB")
        XCTAssertEqual(snapshot.capacityBytes, 2_000_000_000)
        XCTAssertEqual(snapshot.statusCode, 1) // 1 represents Warning status
        XCTAssertEqual(snapshot.temperature, 35)
        XCTAssertEqual(snapshot.powerOnHours, 500)
        XCTAssertEqual(snapshot.collectorDate, "2023-10-28T12:00:00Z")

        // Derived properties
        XCTAssertEqual(snapshot.status, DriveStatus(statusCode: 1))
        XCTAssertEqual(snapshot.temperatureText, "35 C")
        XCTAssertEqual(snapshot.powerOnHoursText, "500 h")
        XCTAssertEqual(snapshot.capacityText, "2 GB")
    }

    func testDecodeWithMissingOptionalFields() throws {
        let jsonString = """
        {
            "id": "drive-3",
            "name": "Unknown Drive",
            "model": "Generic Model",
            "serial": "UNKNOWN",
            "protocolName": "SATA"
        }
        """

        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(DriveSnapshot.self, from: jsonData)

        XCTAssertEqual(snapshot.id, "drive-3")
        XCTAssertEqual(snapshot.name, "Unknown Drive")
        XCTAssertEqual(snapshot.model, "Generic Model")
        XCTAssertEqual(snapshot.serial, "UNKNOWN")
        XCTAssertEqual(snapshot.protocolName, "SATA")
        
        XCTAssertNil(snapshot.capacityBytes)
        XCTAssertNil(snapshot.statusCode)
        XCTAssertNil(snapshot.temperature)
        XCTAssertNil(snapshot.powerOnHours)
        XCTAssertNil(snapshot.collectorDate)

        // Derived properties
        XCTAssertEqual(snapshot.status, DriveStatus(statusCode: nil))
        XCTAssertEqual(snapshot.temperatureText, "-")
        XCTAssertEqual(snapshot.powerOnHoursText, "-")
        XCTAssertEqual(snapshot.capacityText, "Unknown")
    }

    func testDecodeMissingRequiredKeyThrowsKeyNotFound() throws {
        let jsonString = """
        {
            "name": "Test",
            "model": "Model",
            "serial": "123",
            "protocolName": "NVMe"
        }
        """
        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(DriveSnapshot.self, from: jsonData)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            if case .keyNotFound(let key, _) = decodingError {
                XCTAssertEqual(key.stringValue, "id")
            } else {
                XCTFail("Expected keyNotFound, got \(decodingError)")
            }
        }
    }

    func testDecodeTypeMismatchThrowsTypeMismatch() throws {
        let jsonString = """
        {
            "id": "drive-1",
            "name": "Test",
            "model": "Model",
            "serial": "123",
            "protocolName": "NVMe",
            "capacityBytes": "NotAnInteger"
        }
        """
        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(DriveSnapshot.self, from: jsonData)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            if case .typeMismatch(let type, let context) = decodingError {
                XCTAssertEqual(ObjectIdentifier(type), ObjectIdentifier(Int64.self))
                XCTAssertEqual(context.codingPath.last?.stringValue, "capacityBytes")
            } else {
                XCTFail("Expected typeMismatch, got \(decodingError)")
            }
        }
    }

    func testDecodeExplicitNullForRequiredKeyThrowsValueNotFound() throws {
        let jsonString = """
        {
            "id": null,
            "name": "Test",
            "model": "Model",
            "serial": "123",
            "protocolName": "NVMe"
        }
        """
        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(DriveSnapshot.self, from: jsonData)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError, got \(error)")
                return
            }
            if case .valueNotFound(let type, _) = decodingError {
                XCTAssertEqual(ObjectIdentifier(type), ObjectIdentifier(String.self))
            } else {
                XCTFail("Expected valueNotFound, got \(decodingError)")
            }
        }
    }

    func testDecodeExplicitNullOptionalFields() throws {
        let jsonString = """
        {
            "id": "drive-3",
            "name": "Unknown Drive",
            "model": "Generic Model",
            "serial": "UNKNOWN",
            "protocolName": "SATA",
            "capacityBytes": null,
            "statusCode": null,
            "temperature": null,
            "powerOnHours": null,
            "collectorDate": null
        }
        """
        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(DriveSnapshot.self, from: jsonData)

        XCTAssertEqual(snapshot.id, "drive-3")
        XCTAssertNil(snapshot.capacityBytes)
        XCTAssertNil(snapshot.statusCode)
        XCTAssertNil(snapshot.temperature)
        XCTAssertNil(snapshot.powerOnHours)
        XCTAssertNil(snapshot.collectorDate)

        // Derived properties
        XCTAssertEqual(snapshot.status, DriveStatus(statusCode: nil))
        XCTAssertEqual(snapshot.temperatureText, "-")
        XCTAssertEqual(snapshot.powerOnHoursText, "-")
        XCTAssertEqual(snapshot.capacityText, "Unknown")
    }
    func testTemperatureValidationValidValue() {
        let snapshot = DriveSnapshot(
            id: "1", name: "A", model: "B", serial: "C", protocolName: "D",
            capacityBytes: nil, statusCode: nil, temperature: 40, powerOnHours: nil, collectorDate: nil
        )
        XCTAssertEqual(snapshot.temperature, 40)
    }

    func testTemperatureValidationExactLowerBound() {
        let snapshot = DriveSnapshot(
            id: "1", name: "A", model: "B", serial: "C", protocolName: "D",
            capacityBytes: nil, statusCode: nil, temperature: DriveSnapshot.minPlausibleTemperature, powerOnHours: nil, collectorDate: nil
        )
        XCTAssertEqual(snapshot.temperature, DriveSnapshot.minPlausibleTemperature)
    }

    func testTemperatureValidationExactUpperBound() {
        let snapshot = DriveSnapshot(
            id: "1", name: "A", model: "B", serial: "C", protocolName: "D",
            capacityBytes: nil, statusCode: nil, temperature: DriveSnapshot.maxPlausibleTemperature, powerOnHours: nil, collectorDate: nil
        )
        XCTAssertEqual(snapshot.temperature, DriveSnapshot.maxPlausibleTemperature)
    }

    func testTemperatureValidationBelowLowerBound() {
        let snapshot = DriveSnapshot(
            id: "1", name: "A", model: "B", serial: "C", protocolName: "D",
            capacityBytes: nil, statusCode: nil, temperature: DriveSnapshot.minPlausibleTemperature - 1, powerOnHours: nil, collectorDate: nil
        )
        XCTAssertNil(snapshot.temperature)
    }

    func testTemperatureValidationAboveUpperBound() {
        let snapshot = DriveSnapshot(
            id: "1", name: "A", model: "B", serial: "C", protocolName: "D",
            capacityBytes: nil, statusCode: nil, temperature: DriveSnapshot.maxPlausibleTemperature + 1, powerOnHours: nil, collectorDate: nil
        )
        XCTAssertNil(snapshot.temperature)
    }

    func testNegativeCapacityBytesValidation() {
        let snapshot = DriveSnapshot(
            id: "1", name: "A", model: "B", serial: "C", protocolName: "D",
            capacityBytes: -100, statusCode: nil, temperature: nil, powerOnHours: nil, collectorDate: nil
        )
        XCTAssertNil(snapshot.capacityBytes)
    }

    func testNegativePowerOnHoursValidation() {
        let snapshot = DriveSnapshot(
            id: "1", name: "A", model: "B", serial: "C", protocolName: "D",
            capacityBytes: nil, statusCode: nil, temperature: nil, powerOnHours: -5, collectorDate: nil
        )
        XCTAssertNil(snapshot.powerOnHours)
    }
}
