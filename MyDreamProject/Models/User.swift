import Foundation

/// 로그인한 사람 한 명의 정보
struct User: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var role: Role
}
