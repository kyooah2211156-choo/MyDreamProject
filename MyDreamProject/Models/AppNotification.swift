import Foundation

/// 앱 안에서 보여주는 알림 (예: 반려견 등록 승인/반려)
struct AppNotification: Identifiable, Codable, Hashable {
    let id: String
    var recipientID: String
    var title: String
    var content: String
    var isRead: Bool
    var date: Date
}
