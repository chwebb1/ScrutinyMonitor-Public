import XCTest
@testable import ScrutinyMonitor

final class AppPreferencesTests: XCTestCase {

    func testKeysAreCorrect() {
        XCTAssertEqual(AppPreferences.autoRefreshEnabledKey, "ScrutinyMonitor.autoRefreshEnabled")
        XCTAssertEqual(AppPreferences.autoRefreshIntervalKey, "ScrutinyMonitor.autoRefreshInterval")
        XCTAssertEqual(AppPreferences.driveFailureNotificationsEnabledKey, "ScrutinyMonitor.driveFailureNotificationsEnabled")
        XCTAssertEqual(AppPreferences.desktopNotificationsEnabledKey, "ScrutinyMonitor.desktopNotificationsEnabled")
        XCTAssertEqual(AppPreferences.showMenuBarExtraKey, "ScrutinyMonitor.showMenuBarExtra")
    }

    func testDefaultAutoRefreshIntervalIsCorrect() {
        XCTAssertEqual(AppPreferences.defaultAutoRefreshInterval, 300.0)
    }

    func testRefreshIntervalsAreCorrect() {
        let intervals = AppPreferences.refreshIntervals

        XCTAssertEqual(intervals.count, 5)

        // Test first interval
        XCTAssertEqual(intervals[0].title, "Every 1 minute")
        XCTAssertEqual(intervals[0].seconds, 60.0)
        XCTAssertEqual(intervals[0].id, 60.0)

        // Test second interval
        XCTAssertEqual(intervals[1].title, "Every 5 minutes")
        XCTAssertEqual(intervals[1].seconds, 300.0)
        XCTAssertEqual(intervals[1].id, 300.0)

        // Test third interval
        XCTAssertEqual(intervals[2].title, "Every 15 minutes")
        XCTAssertEqual(intervals[2].seconds, 900.0)
        XCTAssertEqual(intervals[2].id, 900.0)

        // Test fourth interval
        XCTAssertEqual(intervals[3].title, "Every 30 minutes")
        XCTAssertEqual(intervals[3].seconds, 1800.0)
        XCTAssertEqual(intervals[3].id, 1800.0)

        // Test fifth interval
        XCTAssertEqual(intervals[4].title, "Every 1 hour")
        XCTAssertEqual(intervals[4].seconds, 3600.0)
        XCTAssertEqual(intervals[4].id, 3600.0)
    }

    func testRefreshIntervalOptionHashableAndEquatable() {
        let option1 = RefreshIntervalOption(title: "Option 1", seconds: 10)
        let option2 = RefreshIntervalOption(title: "Option 1", seconds: 10)
        let option3 = RefreshIntervalOption(title: "Option 2", seconds: 20)

        // Equatable
        XCTAssertEqual(option1, option2)
        XCTAssertNotEqual(option1, option3)

        // Hashable
        XCTAssertEqual(option1.hashValue, option2.hashValue)
        XCTAssertNotEqual(option1.hashValue, option3.hashValue)
    }
}
