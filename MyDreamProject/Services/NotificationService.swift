import Foundation

/// 앱 안 알림을 읽고 쓰는 약속.
/// 실제 푸시(APNs)는 서버 연동 단계에서 이 약속을 따르는 새 클래스로 붙입니다.
protocol NotificationService {
    func load() -> [AppNotification]
    func add(_ notification: AppNotification)
    func markRead(id: String)
    func markAllRead(recipientID: String)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 알림 저장소 (샘플 알림으로 시작)
final class FakeNotificationService: NotificationService {
    private var items = SampleData.notifications

    func load() -> [AppNotification] { items }

    func add(_ notification: AppNotification) {
        items.insert(notification, at: 0)
    }

    func markRead(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isRead = true
    }

    func markAllRead(recipientID: String) {
        for index in items.indices where items[index].recipientID == recipientID {
            items[index].isRead = true
        }
    }
}
