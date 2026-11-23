import Foundation

/// 원장이 선생님에게 주는 일회용 초대 코드
struct StaffInvite: Identifiable, Codable, Hashable {
    let id: String
    var code: String
    var kindergartenID: String
    var createdByID: String
    var createdAt: Date
    var usedByID: String?       // 이 코드로 가입한 선생님

    var isUsed: Bool { usedByID != nil }
}
