import Foundation

/// 앱 사용자의 역할. 로그인한 역할에 따라 화면과 버튼이 달라집니다.
enum Role: String, Codable, CaseIterable, Hashable {
    case owner      // 원장
    case teacher    // 선생님
    case parent     // 보호자

    var displayName: String {
        switch self {
        case .owner: "원장"
        case .teacher: "선생님"
        case .parent: "보호자"
        }
    }
}
