import XCTest
import Combine
import SwiftUI
@testable import ScrutinyMonitor

final class InspectionTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testInspectionVisitInvokesCallbackAndRemovesIt() {
        let inspection = Inspection<String>()
        var invoked = false
        var receivedView: String? = nil

        let callback: (String) -> Void = { view in
            invoked = true
            receivedView = view
        }

        inspection.callbacks[10] = callback

        XCTAssertEqual(inspection.callbacks.count, 1)

        inspection.visit("test_view", 10)

        XCTAssertTrue(invoked)
        XCTAssertEqual(receivedView, "test_view")
        XCTAssertEqual(inspection.callbacks.count, 0)
    }

    func testInspectionVisitIgnoresUnregisteredLine() {
        let inspection = Inspection<String>()
        var invoked = false

        let callback: (String) -> Void = { _ in
            invoked = true
        }

        inspection.callbacks[10] = callback

        XCTAssertEqual(inspection.callbacks.count, 1)

        inspection.visit("test_view", 20)

        XCTAssertFalse(invoked)
        XCTAssertEqual(inspection.callbacks.count, 1)
    }

    func testReceiveDoesNotCrash() {
        let inspection = Inspection<String>()
        // Should do nothing, just testing it doesn't crash or behave unexpectedly
        inspection.receive(10)
    }

    func testNoticeSubjectPublishes() {
        let inspection = Inspection<String>()
        let expectation = XCTestExpectation(description: "Publishes notice")
        var receivedNotice: UInt?

        inspection.notice
            .sink { notice in
                receivedNotice = notice
                expectation.fulfill()
            }
            .store(in: &cancellables)

        inspection.notice.send(42)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedNotice, 42)
    }
}
