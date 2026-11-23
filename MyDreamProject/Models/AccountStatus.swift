import Foundation

/// 계정 상태. 이용 중(active)인 계정만 로그인할 수 있습니다.
enum AccountStatus: String, Codable, Hashable {
    case pending    // 승인 대기 (원장이 가입한 직후)
    case active     // 이용 중
    case rejected   // 가입 반려
    case resigned   // 퇴사 (선생님) - 더 이상 접근할 수 없음
    case suspended  // 이용 중단 (보호자 경고 3회)

    var displayName: String {
        switch self {
        case .pending: "승인 대기"
        case .active: "이용 중"
        case .rejected: "반려됨"
        case .resigned: "퇴사"
        case .suspended: "이용 중단"
        }
    }
}
