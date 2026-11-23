import Foundation
import Observation

/// 앱 안 알림 창고. 안 읽은 알림 개수(배지)도 여기서 셉니다.
@Observable
final class NotificationStore {
    private let service: NotificationService
    private(set) var items: [AppNotification] = []

    init(service: NotificationService = FakeNotificationService()) {
        self.service = service
        reload()
    }

    private func reload() {
        items = service.load()
    }

    /// 내 알림 (최신순)
    func notifications(for user: User) -> [AppNotification] {
        items.filter { $0.recipientID == user.id }.sorted { $0.date > $1.date }
    }

    func unreadCount(for user: User) -> Int {
        items.filter { $0.recipientID == user.id && !$0.isRead }.count
    }

    /// 알림 보내기 (지금은 앱 안 알림만)
    func send(to recipientID: String, title: String, content: String) {
        service.add(AppNotification(id: UUID().uuidString, recipientID: recipientID,
                                    title: title, content: content, isRead: false, date: .now))
        reload()
    }

    func markRead(_ id: String) {
        service.markRead(id: id)
        reload()
    }

    func markAllRead(for user: User) {
        service.markAllRead(recipientID: user.id)
        reload()
    }
}
