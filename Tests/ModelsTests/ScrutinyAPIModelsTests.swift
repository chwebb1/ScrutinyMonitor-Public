import XCTest
@testable import ScrutinyMonitor

final class ScrutinyAPIModelsTests: XCTestCase {

    // MARK: - HealthResponse Tests

    func testDecodeHealthResponse_Success() throws {
        let json = """
        {
            "success": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(HealthResponse.self, from: json)

        XCTAssertTrue(response.success)
        XCTAssertNil(response.error)
        XCTAssertNil(response.errors)
    }

    func testDecodeHealthResponse_Failure() throws {
        let json = """
        {
            "success": false,
            "error": "Failed to connect",
            "errors": ["Failed to connect", "Timeout"]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(HealthResponse.self, from: json)

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, "Failed to connect")
        XCTAssertEqual(response.errors, ["Failed to connect", "Timeout"])
    }

    // MARK: - SummaryResponse Tests

    func testDecodeSummaryResponse_Success() throws {
        let json = """
        {
            "success": true,
            "data": {
                "summary": {}
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(SummaryResponse.self, from: json)

        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.data)
        XCTAssertNil(response.error)
        XCTAssertNil(response.errors)
    }

    func testDecodeSummaryResponse_Failure() throws {
        let json = """
        {
            "success": false,
            "error": "Not found"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(SummaryResponse.self, from: json)

        XCTAssertFalse(response.success)
        XCTAssertNil(response.data)
        XCTAssertEqual(response.error, "Not found")
    }

    // MARK: - ScrutinyDevice Tests

    func testDecodeScrutinyDevice_AllFields() throws {
        let json = """
        {
            "wwn": "0x50014ee2b5c007c6",
            "device_name": "sda",
            "device_uuid": "0f63a3c1",
            "manufacturer": "WD",
            "model_name": "WD Red",
            "serial_number": "WD-WCC4N7KLYL3",
            "firmware": "82.00A82",
            "capacity": 4000787030016,
            "rotational_speed": 5400,
            "device_protocol": "ATA",
            "device_status": 0,
            "scrutiny_uuid": "e44c2c31"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let device = try decoder.decode(ScrutinyDevice.self, from: json)

        XCTAssertEqual(device.wwn, "0x50014ee2b5c007c6")
        XCTAssertEqual(device.deviceName, "sda")
        XCTAssertEqual(device.deviceUUID, "0f63a3c1")
        XCTAssertEqual(device.manufacturer, "WD")
        XCTAssertEqual(device.modelName, "WD Red")
        XCTAssertEqual(device.serialNumber, "WD-WCC4N7KLYL3")
        XCTAssertEqual(device.firmware, "82.00A82")
        XCTAssertEqual(device.capacity, 4000787030016)
        XCTAssertEqual(device.rotationalSpeed, 5400)
        XCTAssertEqual(device.deviceProtocol, "ATA")
        XCTAssertEqual(device.deviceStatus?.value, 0)
        XCTAssertEqual(device.scrutinyUUID, "e44c2c31")
    }

    func testDecodeScrutinyDeviceFlexibleIntFromStringStatus() throws {
        let json = """
        {
            "device_name": "sda",
            "device_status": "1"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let device = try decoder.decode(ScrutinyDevice.self, from: json)

        XCTAssertEqual(device.deviceStatus?.value, 1)
    }

    func testDecodeScrutinyDevice_MissingOptionalFields() throws {
        let json = """
        {
            "wwn": "0x123",
            "device_name": "nvme0n1"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let device = try decoder.decode(ScrutinyDevice.self, from: json)

        XCTAssertEqual(device.wwn, "0x123")
        XCTAssertEqual(device.deviceName, "nvme0n1")
        XCTAssertNil(device.manufacturer)
        XCTAssertNil(device.deviceStatus)
    }

    func testDecodeScrutinyDevice_FlexibleIntFromString() throws {
        let json = """
        {
            "wwn": "0x50014ee2b5c007c6",
            "device_name": "sda",
            "device_status": "2"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let device = try decoder.decode(ScrutinyDevice.self, from: json)

        XCTAssertEqual(device.deviceStatus?.value, 2)
    }

    // MARK: - ScrutinySmart Tests

    func testDecodeScrutinySmart_AllFields() throws {
        let json = """
        {
            "collector_date": "2023-10-27T10:00:00Z",
            "temp": 35,
            "power_on_hours": 12345
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let smart = try decoder.decode(ScrutinySmart.self, from: json)

        XCTAssertEqual(smart.collectorDate, "2023-10-27T10:00:00Z")
        XCTAssertEqual(smart.temp?.value, 35)
        XCTAssertEqual(smart.powerOnHours?.value, 12345)
    }

    func testDecodeScrutinySmartFlexibleIntsFromStrings() throws {
        let json = """
        {
            "collector_date": "2023-10-27T10:00:00Z",
            "temp": "35",
            "power_on_hours": "12345"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let smart = try decoder.decode(ScrutinySmart.self, from: json)

        XCTAssertEqual(smart.temp?.value, 35)
        XCTAssertEqual(smart.powerOnHours?.value, 12345)
    }

    func testDecodeScrutinySmart_MissingOptionalFields() throws {
        let json = """
        {
            "collector_date": "2023-10-27T10:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let smart = try decoder.decode(ScrutinySmart.self, from: json)

        XCTAssertEqual(smart.collectorDate, "2023-10-27T10:00:00Z")
        XCTAssertNil(smart.temp)
        XCTAssertNil(smart.powerOnHours)
    }

    // MARK: - SummaryEntry and SummaryData Tests

    func testDecodeSummaryData_WithEntries() throws {
        let json = """
        {
            "summary": {
                "sda": {
                    "device": {
                        "device_name": "sda"
                    },
                    "smart": {
                        "temp": 40
                    }
                },
                "sdb": {
                    "device": {
                        "device_name": "sdb"
                    }
                }
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let data = try decoder.decode(SummaryData.self, from: json)

        XCTAssertEqual(data.summary.count, 2)

        let sda = data.summary["sda"]
        XCTAssertEqual(sda?.device?.deviceName, "sda")
        XCTAssertEqual(sda?.smart?.temp?.value, 40)

        let sdb = data.summary["sdb"]
        XCTAssertEqual(sdb?.device?.deviceName, "sdb")
        XCTAssertNil(sdb?.smart)
    }
}
