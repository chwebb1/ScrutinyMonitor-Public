import XCTest
@testable import ScrutinyMonitor

final class WebDAVSettingsSyncBackendTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        KeychainHelper.resetTestState()
        super.tearDown()
    }

    func testProactiveAuthHeaderIsAddedSecurely() async throws {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        defaults.set("http://webdav.local/test", forKey: SettingsSyncDefaults.webDAVURLKey)
        KeychainHelper.shared.saveData(Data("testuser".utf8), service: SettingsSyncDefaults.webDAVUsernameService, account: SettingsSyncDefaults.webDAVUsernameAccount)
        KeychainHelper.shared.saveData(Data("testpass".utf8), service: SettingsSyncDefaults.webDAVPasswordService, account: SettingsSyncDefaults.webDAVPasswordAccount)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        let expectedPayload = SettingsSyncPayload()
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(expectedPayload)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payloadData)
        }

        let payload = try await backend.loadPayload()
        XCTAssertEqual(payload?.preferences, expectedPayload.preferences)
    }

    func testLoadPayloadMissingHTTPResponse() async {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        defaults.set("http://webdav.local/test", forKey: SettingsSyncDefaults.webDAVURLKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        MockURLProtocol.requestHandler = { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (response, Data())
        }

        do {
            _ = try await backend.loadPayload()
            XCTFail("Expected loadPayload to throw")
        } catch SettingsSyncError.missingHTTPResponse {
            // Expected
        } catch {
            XCTFail("Expected missingHTTPResponse, got: \(error)")
        }
    }

    func testLoadPayload404ReturnsNil() async throws {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        defaults.set("http://webdav.local/test", forKey: SettingsSyncDefaults.webDAVURLKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let payload = try await backend.loadPayload()
        XCTAssertNil(payload, "Expected loadPayload to return nil on 404")
    }

    func testLoadPayloadServerRejectedRequest() async {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        defaults.set("http://webdav.local/test", forKey: SettingsSyncDefaults.webDAVURLKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await backend.loadPayload()
            XCTFail("Expected loadPayload to throw")
        } catch SettingsSyncError.serverRejectedRequest(let statusCode) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Expected serverRejectedRequest, got: \(error)")
        }
    }

    func testLoadPayloadInsecureURL() async {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        // Using a public HTTP URL
        defaults.set("http://example.com/webdav", forKey: SettingsSyncDefaults.webDAVURLKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        do {
            _ = try await backend.loadPayload()
            XCTFail("Expected loadPayload to throw due to insecure URL")
        } catch SettingsSyncError.insecureWebDAVURL {
            // Expected
        } catch {
            XCTFail("Expected insecureWebDAVURL error, got: \(error)")
        }
    }

    @MainActor
    func testStartAndStopObserving() async throws {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        actor ExpectationHolder {
            var expectation: XCTestExpectation?
            func set(_ newExpectation: XCTestExpectation) { expectation = newExpectation }
            func fulfill() { expectation?.fulfill() }
        }
        let holder = ExpectationHolder()

        let expectation = XCTestExpectation(description: "Observer not called immediately")
        expectation.isInverted = true
        await holder.set(expectation)

        // The test verifies that startObserving (which sleeps for 60s) does not fire immediately
        backend.startObserving {
            Task { @MainActor in await holder.fulfill() }
        }

        // Wait slightly to ensure observer block is not spuriously triggered
        try await Task.sleep(nanoseconds: 100_000_000)
        await fulfillment(of: [expectation], timeout: 0.1)

        backend.stopObserving()

        let expectation2 = XCTestExpectation(description: "Observer not called after stop")
        expectation2.isInverted = true
        await holder.set(expectation2)
        try await Task.sleep(nanoseconds: 100_000_000)
        await fulfillment(of: [expectation2], timeout: 0.1)
    }

    func testLoadPayloadSuccess() async throws {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        defaults.set("http://webdav.local/test", forKey: SettingsSyncDefaults.webDAVURLKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        let expectedPayload = SettingsSyncPayload()
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(expectedPayload)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payloadData)
        }

        let payload = try await backend.loadPayload()
        XCTAssertEqual(payload?.preferences, expectedPayload.preferences)
    }

    func testSavePayloadMissingHTTPResponse() async {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        defaults.set("http://webdav.local/test", forKey: SettingsSyncDefaults.webDAVURLKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        MockURLProtocol.requestHandler = { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (response, Data())
        }

        do {
            try await backend.savePayload(SettingsSyncPayload())
            XCTFail("Expected savePayload to throw")
        } catch SettingsSyncError.missingHTTPResponse {
            // Expected
        } catch {
            XCTFail("Expected missingHTTPResponse, got: \(error)")
        }
    }

    func testSavePayloadServerRejectedRequest() async {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        defaults.set("http://webdav.local/test", forKey: SettingsSyncDefaults.webDAVURLKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            try await backend.savePayload(SettingsSyncPayload())
            XCTFail("Expected savePayload to throw")
        } catch SettingsSyncError.serverRejectedRequest(let statusCode) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Expected serverRejectedRequest, got: \(error)")
        }
    }

    func testSavePayloadSuccess() async throws {
        let defaultsName = "WebDAVSettingsSyncBackendTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            XCTFail("Failed to create ephemeral UserDefaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        defaults.set("http://webdav.local/test", forKey: SettingsSyncDefaults.webDAVURLKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let backend = WebDAVSettingsSyncBackend(defaults: defaults, session: session)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await backend.savePayload(SettingsSyncPayload())
        // Should not throw
    }
}
