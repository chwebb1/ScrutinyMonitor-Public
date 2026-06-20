import AppKit
import SwiftUI

enum DriveGridColumnSizing {
    static let buttonWidth: CGFloat = 36
    private static let textPadding: CGFloat = 14

    static func measuredTextColumn(title: String, values: [String], minimum: CGFloat = 0) -> GridItem {
        let headerWidth = measuredWidth(title, font: .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold))

        // ⚡ Bolt: Replace `.map {}.max()` with imperative loop to avoid an intermediate
        // array allocation containing string sizes on every SwiftUI layout pass.
        // Also caches the font reference outside the loop to avoid redundant initialization.
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        var maxValueWidth: CGFloat = 0
        for value in values {
            let width = measuredWidth(value, font: font)
            if width > maxValueWidth {
                maxValueWidth = width
            }
        }

        return GridItem(.fixed(max(minimum, headerWidth, maxValueWidth) + textPadding), alignment: .leading)
    }

    static func modelColumn(minimum: CGFloat = 80) -> GridItem {
        GridItem(.flexible(minimum: minimum), alignment: .leading)
    }

    static func buttonColumn() -> GridItem {
        GridItem(.fixed(buttonWidth), alignment: .center)
    }

    private static func measuredWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}
