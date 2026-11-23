import Foundation

/// 로그인한 사람 한 명의 정보
struct User: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var role: Role
    var status: AccountStatus = .active     // 이용 중인 계정만 로그인 가능
    var kindergartenID: String? = nil       // 소속 유치원 (원장·선생님)
    var warningCount: Int = 0               // 운영규칙 경고 횟수 (보호자, 원장이 직접 기록)
}
