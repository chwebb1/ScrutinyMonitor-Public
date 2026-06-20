import XCTest
import Security
@testable import ScrutinyMonitor

/// A minimal thread-safe box for sharing mutable state with `@Sendable` closures in tests.
/// `@unchecked Sendable` is safe here because all access is serialized through `NSLock`.
private final class TestStateBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { _value = value }
    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

final class KeychainHelperTests: XCTestCase {
    let testService = "com.scrutinymonitor.test.service"
    let testAccount = "testAccount"
    let testString = "super-secret-test-string"

    override func setUp() {
        super.setUp()
        // Ensure clean state before each test
        KeychainHelper.shared.delete(service: testService, account: testAccount)
    }

    override func tearDown() {
        // Clean up after each test
        KeychainHelper.resetTestState()
        super.tearDown()
    }

    func testSaveAndRead() {
        // Initially, the item should not exist
        let initialRead = KeychainHelper.shared.readData(service: testService, account: testAccount)
        XCTAssertNil(initialRead, "Expected nil when reading non-existent keychain item")

        // Save a string
        KeychainHelper.shared.saveData(testString.data(using: .utf8)!, service: testService, account: testAccount)

        // Read it back
        let savedRead = KeychainHelper.shared.readData(service: testService, account: testAccount)
        XCTAssertEqual(savedRead, testString.data(using: .utf8)!, "The read string should match the saved string")
    }

    func testUpdateExistingItem() {
        // Save the initial string
        KeychainHelper.shared.saveData(testString.data(using: .utf8)!, service: testService, account: testAccount)

        // Ensure it's saved
        var currentRead = KeychainHelper.shared.readData(service: testService, account: testAccount)
        XCTAssertEqual(currentRead, testString.data(using: .utf8)!)

        // Save a new string for the same service and account
        let updatedString = "new-updated-string"
        KeychainHelper.shared.saveData(updatedString.data(using: .utf8)!, service: testService, account: testAccount)

        // Read it back
        currentRead = KeychainHelper.shared.readData(service: testService, account: testAccount)
        XCTAssertEqual(currentRead, updatedString.data(using: .utf8)!, "The string should be updated to the new value")
    }

    func testDelete() {
        // Save a string
        KeychainHelper.shared.saveData(testString.data(using: .utf8)!, service: testService, account: testAccount)

        // Ensure it's saved
        let savedRead = KeychainHelper.shared.readData(service: testService, account: testAccount)
        XCTAssertEqual(savedRead, testString.data(using: .utf8)!)

        // Delete it
        KeychainHelper.shared.delete(service: testService, account: testAccount)

        // Ensure it's gone
        let afterDeleteRead = KeychainHelper.shared.readData(service: testService, account: testAccount)
        XCTAssertNil(afterDeleteRead, "Expected nil after the keychain item has been deleted")
    }

    func testDeleteNonExistentItem() {
        let nonExistentAccount = "nonExistent"
        defer { KeychainHelper.shared.delete(service: testService, account: nonExistentAccount) }

        // This should run without throwing any errors or crashing
        KeychainHelper.shared.delete(service: testService, account: nonExistentAccount)
    }

    func testDeleteLeavesOtherAccountsIntact() {
        let account1 = "account1"
        let account2 = "account2"
        let data1 = "data1".data(using: .utf8)!
        let data2 = "data2".data(using: .utf8)!

        defer {
            KeychainHelper.shared.delete(service: testService, account: account1)
            KeychainHelper.shared.delete(service: testService, account: account2)
        }

        KeychainHelper.shared.saveData(data1, service: testService, account: account1)
        KeychainHelper.shared.saveData(data2, service: testService, account: account2)

        // Delete account1
        KeychainHelper.shared.delete(service: testService, account: account1)

        // Verify account1 is deleted
        XCTAssertNil(KeychainHelper.shared.readData(service: testService, account: account1))

        // Verify account2 is still present
        XCTAssertEqual(KeychainHelper.shared.readData(service: testService, account: account2), data2)
    }

    func testReadAllData() {
        let account1 = "readAll1"
        let account2 = "readAll2"
        let data1 = "dataA".data(using: .utf8)!
        let data2 = "dataB".data(using: .utf8)!

        defer {
            KeychainHelper.shared.delete(service: testService, account: account1)
            KeychainHelper.shared.delete(service: testService, account: account2)
        }

        // Save data
        KeychainHelper.shared.saveData(data1, service: testService, account: account1)
        KeychainHelper.shared.saveData(data2, service: testService, account: account2)

        let allData = KeychainHelper.shared.readAllData(service: testService)

        XCTAssertEqual(allData[account1], data1)
        XCTAssertEqual(allData[account2], data2)
    }

    func testUpdateExistingItemFailsAndRetries() {
        KeychainHelper.overrides.forceRealImplementationForTesting = true
        defer { KeychainHelper.overrides.forceRealImplementationForTesting = false }

        let addCallCount = TestStateBox(0)
        let updateCallCount = TestStateBox(0)
        let deleteCallCount = TestStateBox(0)
        let retryDataSaved = TestStateBox<Data?>(nil)

        KeychainHelper.overrides.secItemAddOverride = { query, _ in
            addCallCount.value += 1
            if addCallCount.value == 1 {
                return errSecDuplicateItem // Initial save finds duplicate
            } else {
                if let dict = query as? [String: Any] {
                    retryDataSaved.value = dict[kSecValueData as String] as? Data
                }
                return errSecSuccess // Retry after delete succeeds
            }
        }

        KeychainHelper.overrides.secItemUpdateOverride = { _, _ in
            updateCallCount.value += 1
            return errSecParam // Update fails
        }

        KeychainHelper.overrides.secItemDeleteOverride = { _ in
            deleteCallCount.value += 1
            return errSecSuccess // Delete succeeds
        }

        KeychainHelper.shared.saveData(testString.data(using: .utf8)!, service: testService, account: testAccount)

        XCTAssertEqual(addCallCount.value, 2, "Expected add to be called twice: once initially, once on retry")
        XCTAssertEqual(updateCallCount.value, 1, "Expected update to be called once and fail")
        XCTAssertEqual(deleteCallCount.value, 1, "Expected delete to be called once as fallback after failed update")
        XCTAssertEqual(retryDataSaved.value, testString.data(using: .utf8)!, "Expected the retry to attempt saving the correct data")
    }

    func testOverridesInIsolation() {
        KeychainHelper.overrides.forceRealImplementationForTesting = true
        defer { KeychainHelper.overrides.forceRealImplementationForTesting = false }

        let added = TestStateBox(false)
        KeychainHelper.overrides.secItemAddOverride = { _, _ in added.value = true; return errSecSuccess }
        KeychainHelper.shared.saveData(testString.data(using: .utf8)!, service: testService, account: testAccount)
        XCTAssertTrue(added.value)

        let deleted = TestStateBox(false)
        KeychainHelper.overrides.secItemDeleteOverride = { _ in deleted.value = true; return errSecSuccess }
        KeychainHelper.shared.delete(service: testService, account: testAccount)
        XCTAssertTrue(deleted.value)
    }

    func testCopyMatchingOverride() {
        KeychainHelper.overrides.forceRealImplementationForTesting = true
        defer { KeychainHelper.overrides.forceRealImplementationForTesting = false }

        let expectedData = testString.data(using: .utf8)!
        let copyMatchingCalled = TestStateBox(false)

        // Intercept SecItemCopyMatching and return mocked data
        KeychainHelper.overrides.secItemCopyMatchingOverride = { _, resultPtr in
            copyMatchingCalled.value = true
            resultPtr?.pointee = expectedData as CFTypeRef
            return errSecSuccess
        }

        let result = KeychainHelper.shared.readData(service: testService, account: testAccount)

        XCTAssertTrue(copyMatchingCalled.value, "Expected secItemCopyMatchingOverride to be invoked")
        XCTAssertEqual(result, expectedData, "Expected readData to return the mocked data")
    }
}
