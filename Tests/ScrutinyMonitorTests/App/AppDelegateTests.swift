import XCTest
import AppKit
@testable import ScrutinyMonitor

@MainActor
final class AppDelegateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

    func testApplicationDidFinishLaunchingBailsOutDuringTests() {
        let delegate = AppDelegate()
        
        let initialPolicy = NSApp.activationPolicy()

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // Ensure NSApp activation policy isn't modified during tests
        XCTAssertEqual(NSApp.activationPolicy(), initialPolicy)
    }
}
