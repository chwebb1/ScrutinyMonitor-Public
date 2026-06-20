import XCTest
@testable import ScrutinyMonitor

final class MonitorSelectionTests: XCTestCase {

    func testMonitorSelectionEquality() {
        let uuid1 = UUID()
        let uuid2 = UUID()

        // Test equality
        XCTAssertEqual(MonitorSelection.overview, MonitorSelection.overview)
        XCTAssertEqual(MonitorSelection.installation(uuid1), MonitorSelection.installation(uuid1))

        // Test inequality
        XCTAssertNotEqual(MonitorSelection.overview, MonitorSelection.installation(uuid1))
        XCTAssertNotEqual(MonitorSelection.installation(uuid1), MonitorSelection.installation(uuid2))
    }

    func testMonitorSelectionHashable() {
        let uuid1 = UUID()
        let uuid2 = UUID()

        let selection1 = MonitorSelection.overview
        let selection2 = MonitorSelection.overview
        let selection3 = MonitorSelection.installation(uuid1)
        let selection4 = MonitorSelection.installation(uuid1)
        let selection5 = MonitorSelection.installation(uuid2)

        // Test identical values have identical hashes
        XCTAssertEqual(selection1.hashValue, selection2.hashValue)
        XCTAssertEqual(selection3.hashValue, selection4.hashValue)

        // Test different values have different hashes (though strictly hash collisions are possible, they are extremely unlikely for these simple types)
        XCTAssertNotEqual(selection1.hashValue, selection3.hashValue)
        XCTAssertNotEqual(selection3.hashValue, selection5.hashValue)

        // Test Set membership
        var set = Set<MonitorSelection>()
        set.insert(selection1)
        set.insert(selection3)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(.overview))
        XCTAssertTrue(set.contains(.installation(uuid1)))
        XCTAssertFalse(set.contains(.installation(uuid2)))
    }
}
