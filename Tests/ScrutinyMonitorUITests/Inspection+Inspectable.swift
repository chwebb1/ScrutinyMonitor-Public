import ViewInspector
import XCTest
import SwiftUI
@testable import ScrutinyMonitor

extension MenuBarLabel: Inspectable {}

extension Inspection {
    func inspect(after delay: TimeInterval = 0, file: StaticString = #file, line: UInt = #line, _ f: @escaping (V) throws -> Void) -> XCTestExpectation {
        let exp = XCTestExpectation(description: "Inspection")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.callbacks[UInt(exp.hash)] = { view in
                do {
                    try f(view)
                } catch {
                    XCTFail(error.localizedDescription, file: file, line: line)
                }
                exp.fulfill()
            }
            self.notice.send(UInt(exp.hash))
        }
        return exp
    }
}
