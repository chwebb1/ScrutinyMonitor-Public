import XCTest
@testable import ScrutinyMonitor

final class StringFilteringTests: XCTestCase {
    func testRemovingControlCharacters_withControlCharacters() {
        let input = "Hello\nWorld\r\t!"
        let expected = "HelloWorld!"
        XCTAssertEqual(input.removingControlCharacters(), expected)
    }

    func testRemovingControlCharacters_withoutControlCharacters() {
        let input = "Hello World!"
        XCTAssertEqual(input.removingControlCharacters(), input)
    }

    func testRemovingControlCharacters_emptyString() {
        let input = ""
        XCTAssertEqual(input.removingControlCharacters(), "")
    }

    func testRemovingControlCharacters_onlyControlCharacters() {
        let input = "\n\r\t\u{0000}\u{001F}\u{007F}\u{009F}"
        XCTAssertEqual(input.removingControlCharacters(), "")
    }

    func testRemovingControlCharacters_withEmojiAndOtherCharacters() {
        let input = "Hello 🌍!\nHow are you\tdoing?"
        let expected = "Hello 🌍!How are youdoing?"
        XCTAssertEqual(input.removingControlCharacters(), expected)
    }

    func testRemovingControlCharacters_onlyEmoji() {
        let input = "🌍🚀😎"
        XCTAssertEqual(input.removingControlCharacters(), input)
    }
}
