import Foundation

/// 경고 이력의 종류
enum WarningEventKind: String, Codable, Hashable {
    case added      // 경고 추가
    case removed    // 경고 차감(정정)
    case suspended  // 경고 3회 누적으로 이용 중단
    case resumed    // 원장 확인 후 이용 재개

    var displayName: String {
        switch self {
        case .added: String(localized: "경고 추가")
        case .removed: String(localized: "경고 차감")
        case .suspended: String(localized: "이용 중단")
        case .resumed: String(localized: "이용 재개")
        }
    }
}

/// 보호자 경고 이력 한 줄. 날짜·시간과 등록한 직원은 앱이 자동으로 채워요.
struct WarningRecord: Identifiable, Codable, Hashable {
    let id: String
    var parentID: String
    var kind: WarningEventKind
    var reason: String
    var date: Date
    var staffID: String         // 등록·처리한 직원(원장·선생님)
    var countAfter: Int         // 처리 뒤 경고 횟수
}
