import XCTest
import SwiftUI
import ViewInspector
@testable import ScrutinyMonitor

@MainActor
final class DriveDetailViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testDriveDetailViewErrorState() throws {
        let drive = DriveSnapshot(
            id: "1", name: "Drive", model: "Model", serial: "Serial",
            protocolName: "SATA", capacityBytes: 1000, statusCode: 0,
            temperature: 30, powerOnHours: 100, collectorDate: "2023-01-01T00:00:00Z"
        )
        let installation = ScrutinyInstallation(id: UUID(), name: "Local", baseURL: URL(string: "http://localhost:8080")!, apiToken: Data())

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockClient = ScrutinyClient(sessionConfiguration: configuration)

        // Set up the mock protocol to return an error
        MockURLProtocol.requestHandler = { request in
            throw ScrutinyClientError.api("Test error message")
        }
        
        let view = DriveDetailView(installation: installation, drive: drive, client: mockClient)

        let exp = view.inspection.inspect(after: 0.5) { view in
            let unavailableView = try view.inspect().find(ViewType.ContentUnavailableView.self)
            XCTAssertNotNil(unavailableView)
        }

        ViewHosting.host(view: view)
        wait(for: [exp], timeout: 2.0)
    }
}
