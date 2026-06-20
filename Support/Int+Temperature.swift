import SwiftUI

extension Int {
    var temperatureColor: Color {
        if self >= 50 {
            return .red
        } else if self >= 40 {
            return .orange
        } else {
            return .green
        }
    }
}
