import Foundation

final class NotificationToken {
    private let token: any NSObjectProtocol
    private let center: NotificationCenter

    init(token: any NSObjectProtocol, center: NotificationCenter = .default) {
        self.token = token
        self.center = center
    }

    deinit {
        center.removeObserver(token)
    }
}
