import XCTest
import SwiftUI
import Combine
@testable import ScrutinyMonitor

final class InspectionSupportTests: XCTestCase {

    func testVisitExecutesCallback() {
        let inspection = Inspection<AnyView>()
        var executed = false

        inspection.callbacks[42] = { _ in
            executed = true
        }

        let view = AnyView(Text("Test"))
        inspection.visit(view, 42)

        XCTAssertTrue(executed)
    }

    func testVisitRemovesCallback() {
        let inspection = Inspection<AnyView>()

        inspection.callbacks[42] = { _ in }

        let view = AnyView(Text("Test"))
        inspection.visit(view, 42)

        XCTAssertNil(inspection.callbacks[42])
    }

    func testReceiveDoesNotCrash() {
        let inspection = Inspection<AnyView>()
        inspection.receive(42)
        XCTAssertTrue(true, "receive should not crash")
    }
}
