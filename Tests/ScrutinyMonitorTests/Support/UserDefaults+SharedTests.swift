import XCTest
@testable import ScrutinyMonitor

final class UserDefaultsSharedTests: XCTestCase {

    func testAppGroupIdentifier() {
        let identifier = UserDefaults.appGroupIdentifier

        let bundleIdentifier = Bundle.main.object(forInfoDictionaryKey: "ScrutinyMonitorAppGroupIdentifier") as? String

        if let bundleIdentifier = bundleIdentifier {
            XCTAssertEqual(identifier, bundleIdentifier)
        } else {
            XCTAssertEqual(identifier, "group.com.chriswebb.ScrutinyMonitor")
        }
    }

    func testSharedUserDefaults() {
        let sharedDefaults = UserDefaults.shared
        XCTAssertNotNil(sharedDefaults)
    }

    func testSharedUserDefaultsSuite() {
        let testKey = "UserDefaultsSharedTestKey"
        let testValue = "testValue"

        UserDefaults.shared.set(testValue, forKey: testKey)

        let explicitDefaults = UserDefaults(suiteName: UserDefaults.appGroupIdentifier)
        XCTAssertEqual(explicitDefaults?.string(forKey: testKey), testValue)

        // clean up
        UserDefaults.shared.removeObject(forKey: testKey)
    }

}
