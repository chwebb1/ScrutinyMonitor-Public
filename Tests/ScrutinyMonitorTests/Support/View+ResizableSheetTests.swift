import XCTest
import SwiftUI
@testable import ScrutinyMonitor

@MainActor
final class ViewResizableSheetTests: XCTestCase {

    func testResizableSheetModifierAddsResizableMask() {
        let view = Text("Test").resizableSheet()
        let nsView = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = nsView

        nsView.layout()

        XCTAssertFalse(window.styleMask.contains(.resizable))

        let expectation = XCTestExpectation(description: "Wait for async update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(window.styleMask.contains(.resizable))
    }

    func testResizableSheetModifierDoesNotCrashWithoutWindow() {
        let view = Text("Test").resizableSheet()
        let nsView = NSHostingView(rootView: view)

        nsView.layout()

        let expectation = XCTestExpectation(description: "Wait for async update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}