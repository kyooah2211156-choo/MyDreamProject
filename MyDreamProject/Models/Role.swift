import Foundation

/// 앱 사용자의 역할. 로그인한 역할에 따라 화면과 버튼이 달라집니다.
enum Role: String, Codable, CaseIterable, Hashable {
    case owner      // 원장
    case teacher    // 선생님
    case parent     // 보호자
    case admin      // 서비스 운영자 (원장 가입을 승인)

    var displayName: String {
        switch self {
        case .owner: String(localized: "원장")
        case .teacher: String(localized: "선생님")
        case .parent: String(localized: "보호자")
        case .admin: String(localized: "운영자")
        }
    }
}
