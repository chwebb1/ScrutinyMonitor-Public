import XCTest
@testable import ScrutinyMonitor

private final class SafeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() -> Int { lock.withLock { count += 1; return count } }
    func get() -> Int { lock.withLock { count } }
}

private final class SafeRequestCounts: @unchecked Sendable {
    private let lock = NSLock()
    private var counts = [String: Int]()
    func increment(for key: String) { lock.withLock { counts[key, default: 0] += 1 } }
    func get() -> [String: Int] { lock.withLock { counts } }
}

final class ScrutinyClientTests: XCTestCase {
    var client: ScrutinyClient!
    var installation: ScrutinyInstallation!

    override func setUp() {
        super.setUp()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        client = ScrutinyClient(sessionConfiguration: configuration, sleepFunction: { _ in })

        installation = ScrutinyInstallation(
            name: "Test Installation",
            baseURL: URL(string: "https://localhost:8080")!,
            apiToken: "test-token".data(using: .utf8)!
        )
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        installation = nil
        super.tearDown()
    }

    func testFetchSnapshotSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            guard let urlString = request.url?.absoluteString else {
                XCTFail("Request URL is nil")
                throw URLError(.badURL)
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if urlString.hasSuffix("/api/health") {
                let healthJSON = """
                {
                    "success": true
                }
                """.data(using: .utf8)!
                return (response, healthJSON)
            } else if urlString.hasSuffix("/api/summary") {
                let summaryJSON = """
                {
                    "success": true,
                    "data": {
                        "summary": {
                            "drive-1": {
                                "device": {
                                    "wwn": "wwn-1",
                                    "device_name": "/dev/sda",
                                    "model_name": "Test Drive",
                                    "device_status": 0
                                },
                                "smart": {
                                    "temp": 35
                                }
                            }
                        }
                    }
                }
                """.data(using: .utf8)!
                return (response, summaryJSON)
            }

            XCTFail("Unexpected request: \(urlString)")
            throw URLError(.badURL)
        }

        let snapshot = try await client.fetchSnapshot(for: installation)
        XCTAssertTrue(snapshot.healthOK)
        XCTAssertEqual(snapshot.totalDrives, 1)
        XCTAssertEqual(snapshot.devices.count, 1)
        XCTAssertEqual(snapshot.devices.first?.id, "wwn-1")
        XCTAssertEqual(snapshot.devices.first?.name, "/dev/sda")
        XCTAssertEqual(snapshot.devices.first?.temperature, 35)
        XCTAssertEqual(snapshot.healthyDrives, 1)
        XCTAssertEqual(snapshot.warningDrives, 0)
        XCTAssertEqual(snapshot.criticalDrives, 0)
    }

    func testFetchSnapshotCountsDeviceStatuses() async throws {
        MockURLProtocol.requestHandler = { request in
            guard let urlString = request.url?.absoluteString else {
                XCTFail("Request URL is nil")
                throw URLError(.badURL)
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if urlString.hasSuffix("/api/health") {
                let healthJSON = """
                {
                    "success": true
                }
                """.data(using: .utf8)!
                return (response, healthJSON)
            } else if urlString.hasSuffix("/api/summary") {
                let summaryJSON = """
                {
                    "success": true,
                    "data": {
                        "summary": {
                            "drive-passed": {
                                "device": { "wwn": "wwn-passed", "device_name": "sda", "device_status": 0 }
                            },
                            "drive-warning": {
                                "device": { "wwn": "wwn-warning", "device_name": "sdb", "device_status": 1 }
                            },
                            "drive-failed": {
                                "device": { "wwn": "wwn-failed", "device_name": "sdc", "device_status": 2 }
                            },
                            "drive-failed-2": {
                                "device": { "wwn": "wwn-failed-2", "device_name": "sdd", "device_status": 3 }
                            },
                            "drive-unknown": {
                                "device": { "wwn": "wwn-unknown", "device_name": "sde" }
                            }
                        }
                    }
                }
                """.data(using: .utf8)!
                return (response, summaryJSON)
            }

            XCTFail("Unexpected request: \(urlString)")
            throw URLError(.badURL)
        }

        let snapshot = try await client.fetchSnapshot(for: installation)
        XCTAssertTrue(snapshot.healthOK)
        XCTAssertEqual(snapshot.totalDrives, 5)
        XCTAssertEqual(snapshot.devices.count, 5)
        XCTAssertEqual(snapshot.healthyDrives, 1)
        XCTAssertEqual(snapshot.warningDrives, 1)
        XCTAssertEqual(snapshot.criticalDrives, 2)
    }

    func testFetchSnapshotHealthFailed() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if request.url!.absoluteString.hasSuffix("/api/health") {
                let healthJSON = """
                {
                    "success": false,
                    "error": "Database disconnected"
                }
                """.data(using: .utf8)!
                return (response, healthJSON)
            } else if request.url!.absoluteString.hasSuffix("/api/summary") {
                let summaryJSON = """
                {
                    "success": true,
                    "data": { "summary": {} }
                }
                """.data(using: .utf8)!
                return (response, summaryJSON)
            }

            throw URLError(.badURL)
        }

        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw an error")
        } catch ScrutinyClientError.api(let message) {
            XCTAssertEqual(message, "Database disconnected")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchSnapshotHealthHTTPError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw an error for HTTP 503")
        } catch ScrutinyClientError.httpStatus(let status) {
            XCTAssertEqual(status, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchDriveDetailSuccess() async throws {
        let drive = DriveSnapshot(
            id: "wwn-1",
            name: "/dev/sda",
            model: "Test Drive",
            serial: "12345",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("/api/device/wwn-1/details"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "success": true,
                "data": {
                    "device": {
                        "wwn": "wwn-1",
                        "device_name": "/dev/sda"
                    },
                    "smart_results": [
                        {
                            "temp": 35
                        }
                    ]
                }
            }
            """.data(using: .utf8)!
            return (response, json)
        }

        let detail = try await client.fetchDriveDetail(for: drive, installation: installation)
        XCTAssertEqual(detail.id, "wwn-1")
        XCTAssertEqual(detail.device?.wwn, "wwn-1")
        XCTAssertEqual(detail.latestSmart?.temperature?.value, 35)
    }

    func testFetchDriveDetailEncodesSlashInDriveID() async throws {
        let drive = DriveSnapshot(
            id: "wwn/1",
            name: "/dev/sda",
            model: "Test Drive",
            serial: "12345",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        MockURLProtocol.requestHandler = { request in
            let urlString = try XCTUnwrap(request.url?.absoluteString)
            XCTAssertTrue(urlString.hasSuffix("/api/device/wwn%2F1/details"))
            XCTAssertFalse(urlString.hasSuffix("/api/device/wwn/1/details"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "success": true,
                "data": {
                    "device": { "wwn": "wwn/1" },
                    "smart_results": []
                }
            }
            """.data(using: .utf8)!
            return (response, json)
        }

        let detail = try await client.fetchDriveDetail(for: drive, installation: installation)
        XCTAssertEqual(detail.id, "wwn/1")
        XCTAssertEqual(detail.device?.wwn, "wwn/1")
    }

    func testFetchDriveDetailEncodesLiteralPercentInDriveID() async throws {
        let drive = DriveSnapshot(
            id: "wwn%2F1",
            name: "/dev/sda",
            model: "Test Drive",
            serial: "12345",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        MockURLProtocol.requestHandler = { request in
            let urlString = try XCTUnwrap(request.url?.absoluteString)
            XCTAssertTrue(urlString.hasSuffix("/api/device/wwn%252F1/details"))
            XCTAssertFalse(urlString.hasSuffix("/api/device/wwn%2F1/details"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "success": true,
                "data": {
                    "device": { "wwn": "wwn%2F1" },
                    "smart_results": []
                }
            }
            """.data(using: .utf8)!
            return (response, json)
        }

        let detail = try await client.fetchDriveDetail(for: drive, installation: installation)
        XCTAssertEqual(detail.id, "wwn%2F1")
        XCTAssertEqual(detail.device?.wwn, "wwn%2F1")
    }

    func testFetchDriveDetailHTTPError() async {
        let drive = DriveSnapshot(
            id: "wwn-1",
            name: "/dev/sda",
            model: "Test Drive",
            serial: "12345",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await client.fetchDriveDetail(for: drive, installation: installation)
            XCTFail("Expected fetchDriveDetail to throw an error")
        } catch ScrutinyClientError.httpStatus(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchSnapshotInsecureTokenTransmission() async {
        installation.baseURL = URL(string: "http://public-server.com")!
        installation.apiToken = "test-token".data(using: .utf8)!

        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw an error due to insecure token transmission")
        } catch ScrutinyClientError.api(let message) {
            XCTAssertEqual(message, "Insecure connection: API token cannot be sent over plain HTTP to a public server.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchSnapshotAllowsTokenTransmissionOnLocalHost() async {
        installation.baseURL = URL(string: "http://192.168.1.100")!
        installation.apiToken = "test-token".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{\"success\": true}".data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await client.fetchSnapshot(for: installation)
        } catch ScrutinyClientError.api(let message) {
            if message.contains("Insecure connection") {
                XCTFail("Should not block local network HTTP token transmission")
            }
        } catch {
            // Other errors (like missing data/parsing) are fine; we just want to ensure the security check allowed it.
        }
    }

    func testFetchSnapshotTokenValidation_ValidToken() async {
        installation.apiToken = "valid-token".data(using: .utf8)!
        
        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "valid-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{\"success\": true}".data(using: .utf8)!
            return (response, data)
        }
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
        } catch { }
        XCTAssertGreaterThan(callCounter.get(), 0)
    }

    func testFetchSnapshotTokenValidation_EmptyData() async {
        installation.apiToken = Data()
        
        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            XCTAssertNil(request.value(forHTTPHeaderField: "X-API-Key"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{\"success\": true}".data(using: .utf8)!
            return (response, data)
        }
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
        } catch {
            // We only care that the request was made without the header
        }
        XCTAssertGreaterThan(callCounter.get(), 0)
    }

    func testFetchSnapshotTokenValidation_WhitespaceOnly() async {
        installation.apiToken = "   \t\n  ".data(using: .utf8)!
        
        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            XCTAssertNil(request.value(forHTTPHeaderField: "X-API-Key"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{\"success\": true}".data(using: .utf8)!
            return (response, data)
        }
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
        } catch { }
        XCTAssertGreaterThan(callCounter.get(), 0)
    }

    func testFetchSnapshotTokenValidation_UnicodeWhitespaceNotTrimmed() async {
        // \u{00A0} is a non-breaking space. Our logic should intentionally preserve it 
        // rather than trimming it away, so it will be sent in the header.
        installation.apiToken = " \u{00A0}valid-token\u{00A0} ".data(using: .utf8)!
        
        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            // The ASCII spaces are trimmed, but the non-breaking spaces remain
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "\u{00A0}valid-token\u{00A0}")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{\"success\": true}".data(using: .utf8)!
            return (response, data)
        }
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
        } catch { }
        XCTAssertGreaterThan(callCounter.get(), 0)
    }

    func testFetchSnapshotTokenValidation_MultiByteUnicodeCharacters() async {
        // Verify that complex multi-byte characters like emojis pass validation 
        // and aren't incorrectly flagged as control characters or invalid UTF-8.
        installation.apiToken = "token-🚀-👨‍👩‍👧‍👦".data(using: .utf8)!
        
        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "token-🚀-👨‍👩‍👧‍👦")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{\"success\": true}".data(using: .utf8)!
            return (response, data)
        }
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
        } catch { }
        XCTAssertGreaterThan(callCounter.get(), 0)
    }

    func testFetchSnapshotTokenValidation_OversizedToken() async {
        let oversizedString = String(repeating: "a", count: 4097)
        installation.apiToken = oversizedString.data(using: .utf8)!
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw an error due to invalid token")
        } catch ScrutinyClientError.api(let message) {
            XCTAssertEqual(message, "Invalid API token format.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchSnapshotTokenValidation_InvalidUTF8() async {
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        installation.apiToken = invalidData
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw an error due to invalid token")
        } catch ScrutinyClientError.api(let message) {
            XCTAssertEqual(message, "Invalid API token format.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchSnapshotTokenValidation_ControlChars() async {
        installation.apiToken = "validprefix\u{0000}validsuffix".data(using: .utf8)!
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw an error due to invalid token")
        } catch ScrutinyClientError.api(let message) {
            XCTAssertEqual(message, "Invalid API token format.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchSnapshotTokenValidation_EdgeCaseControlCharacters() async {
        // Verify that C1 control characters (e.g., 0x85 Next Line) correctly fail validation.
        // This is especially important for our manual UTF-8 decoding loop to catch.
        installation.apiToken = "token\u{0085}".data(using: .utf8)!
        
        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw an error due to C1 control character")
        } catch ScrutinyClientError.api(let message) {
            XCTAssertEqual(message, "Invalid API token format.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchDriveDetailAPIError() async {
        let drive = DriveSnapshot(
            id: "wwn-2",
            name: "/dev/sdb",
            model: "Test Drive 2",
            serial: "12346",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "success": false,
                "error": "Drive not found"
            }
            """.data(using: .utf8)!
            return (response, json)
        }

        do {
            _ = try await client.fetchDriveDetail(for: drive, installation: installation)
            XCTFail("Expected fetchDriveDetail to throw an error")
        } catch ScrutinyClientError.api(let message) {
            XCTAssertEqual(message, "Drive not found")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchDriveDetailDecodingError() async {
        let drive = DriveSnapshot(
            id: "wwn-2",
            name: "/dev/sdb",
            model: "Test Drive 2",
            serial: "12346",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = "{ invalid json".data(using: .utf8)!
            return (response, json)
        }

        do {
            _ = try await client.fetchDriveDetail(for: drive, installation: installation)
            XCTFail("Expected fetchDriveDetail to throw a decoding error")
        } catch ScrutinyClientError.decoding(_) {
            let finalCount = callCounter.get()
            XCTAssertEqual(finalCount, 1, "Expected to fail immediately without retries for decoding errors")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequestRetryOnTransientErrors() async throws {
        let drive = DriveSnapshot(
            id: "wwn-1",
            name: "/dev/sda",
            model: "Test Drive",
            serial: "12345",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            let currentCount = callCounter.increment()
            if currentCount < 3 {
                throw URLError(.timedOut)
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "success": true,
                "data": {
                    "device": {
                        "wwn": "wwn-1",
                        "device_name": "/dev/sda"
                    },
                    "smart_results": [
                        {
                            "temp": 35
                        }
                    ]
                }
            }
            """.data(using: .utf8)!
            return (response, json)
        }

        let detail = try await client.fetchDriveDetail(for: drive, installation: installation)
        let finalCount = callCounter.get()
        XCTAssertEqual(finalCount, 3)
        XCTAssertEqual(detail.id, "wwn-1")
    }

    func testRequestFailsOnPermanentErrors() async {
        let drive = DriveSnapshot(
            id: "wwn-1",
            name: "/dev/sda",
            model: "Test Drive",
            serial: "12345",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            throw URLError(.badServerResponse)
        }

        do {
            _ = try await client.fetchDriveDetail(for: drive, installation: installation)
            XCTFail("Expected call to fail immediately")
        } catch {
            let finalCount = callCounter.get()
            XCTAssertEqual(finalCount, 1)
            XCTAssertTrue(error is URLError)
        }
    }

    func testSnapshotRequestsFailOnMalformedJSONWithoutRetries() async {
        let requestCounts = SafeRequestCounts()
        MockURLProtocol.requestHandler = { request in
            requestCounts.increment(for: request.url?.path ?? "")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = "{ \"success\": true ".data(using: .utf8)!
            return (response, json)
        }

        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw an error due to malformed JSON")
        } catch ScrutinyClientError.decoding {
            let counts = requestCounts.get()

            XCTAssertFalse(counts.isEmpty)
            XCTAssertLessThanOrEqual(counts["/api/health", default: 0], 1)
            XCTAssertLessThanOrEqual(counts["/api/summary", default: 0], 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchSnapshotDecodingError() async {
        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = "{ invalid json".data(using: .utf8)!
            return (response, json)
        }

        do {
            _ = try await client.fetchSnapshot(for: installation)
            XCTFail("Expected fetchSnapshot to throw a decoding error")
        } catch ScrutinyClientError.decoding(let error) {
            let finalCount = callCounter.get()
            // fetchSnapshot makes 2 concurrent requests. It should fail without retrying,
            // so we expect at most 2 requests (1 for health, 1 for summary).
            XCTAssertLessThanOrEqual(finalCount, 2, "Expected to fail immediately without retries for decoding errors")
            XCTAssertTrue(error is Swift.DecodingError, "Expected the underlying error to be a DecodingError")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequestFailsAfterMaxRetriesOnTransientErrors() async {
        let drive = DriveSnapshot(
            id: "wwn-1",
            name: "/dev/sda",
            model: "Test Drive",
            serial: "12345",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            _ = callCounter.increment()
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.fetchDriveDetail(for: drive, installation: installation)
            XCTFail("Expected call to fail eventually")
        } catch {
            let finalCount = callCounter.get()
            XCTAssertEqual(finalCount, 3)
            XCTAssertTrue(error is URLError)
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
    }

    func testRequestSucceedsAfterOneRetryAndVerifiesBackoff() async throws {
        actor SleepTracker {
            private var nanoseconds: [UInt64] = []
            func append(_ val: UInt64) {
                nanoseconds.append(val)
            }
            func get() -> [UInt64] {
                nanoseconds
            }
        }

        let sleepTracker = SleepTracker()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let customClient = ScrutinyClient(
            sessionConfiguration: config,
            sleepFunction: { nanoseconds in
                await sleepTracker.append(nanoseconds)
            }
        )

        let drive = DriveSnapshot(
            id: "wwn-retry",
            name: "/dev/sdc",
            model: "Retry Drive",
            serial: "999",
            protocolName: "ATA",
            capacityBytes: 1000,
            statusCode: 0,
            temperature: 35,
            powerOnHours: 100,
            collectorDate: "2023-10-01"
        )

        let callCounter = SafeCounter()
        MockURLProtocol.requestHandler = { request in
            let currentCount = callCounter.increment()
            if currentCount == 1 {
                throw URLError(.timedOut)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "success": true,
                "data": {
                    "device": {
                        "wwn": "wwn-retry",
                        "device_name": "/dev/sdc"
                    },
                    "smart_results": []
                }
            }
            """.data(using: .utf8)!
            return (response, json)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let detail = try await customClient.fetchDriveDetail(for: drive, installation: installation)
        XCTAssertEqual(detail.id, "wwn-retry")

        let finalCallCount = callCounter.get()
        XCTAssertEqual(finalCallCount, 2, "Expected 2 attempts: 1 failure and 1 success")

        let finalSleeps = await sleepTracker.get()
        XCTAssertEqual(finalSleeps.count, 1, "Expected 1 sleep due to 1 failure")
        XCTAssertEqual(finalSleeps.first, 750_000_000, "First sleep should be 750ms")
    }
}
