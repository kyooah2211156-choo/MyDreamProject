import Foundation
import UserNotifications

/// 기기 알림(화면 위 배너·잠금화면 알림)을 맡는 곳.
/// 서버가 없는 테스트 단계라 진짜 푸시(APNs) 대신, 앱 안 알림이 생길 때 기기 로컬 알림을 함께 띄워요.
/// 서버를 붙이면 이 클래스만 APNs 등록 코드로 바꿔 끼우면 됩니다.
final class DevicePushService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DevicePushService()

    private var center: UNUserNotificationCenter { .current() }

    /// 앱이 켜져 있을 때도 배너로 보이게 합니다. 앱 시작 때 한 번 불러 주세요.
    func configure() {
        center.delegate = self
    }

    /// 기기 알림 권한 요청. 허용하면 true
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 지금 기기에서 알림이 허용돼 있는지 (iOS 설정 앱에서 끌 수도 있어요)
    func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    /// 기기 알림 한 건 띄우기
    func deliver(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        center.add(request)
    }

    /// 끄면 이미 와 있는 알림과 대기 중인 알림을 정리합니다.
    func clearAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
