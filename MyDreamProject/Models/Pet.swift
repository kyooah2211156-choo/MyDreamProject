import Foundation

/// 반려견 등록 상태
enum PetStatus: String, Codable, CaseIterable, Hashable {
    case pending    // 대기중
    case approved   // 승인됨
    case rejected   // 반려됨

    var displayName: String {
        switch self {
        case .pending: String(localized: "대기중")
        case .approved: String(localized: "승인됨")
        case .rejected: String(localized: "반려됨")
        }
    }
}

/// 반려견 한 마리. 보호자 한 명이 여러 마리를 가질 수 있습니다.
/// 승인된(approved) 반려견만 알림장 태그, 사진첩, 선생님 화면에 나타납니다.
struct Pet: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var breed: String
    var profilePhoto: PhotoSource?
    var ownerID: String             // 보호자 User.id
    var status: PetStatus
    var rejectionReason: String?    // 반려됐을 때만 값이 있음
    var requesterID: String         // 등록을 신청한 사람
    var reviewerID: String?         // 승인/반려를 처리한 사람
    var profile: PetProfile?        // 가입 때 적은 상세 정보 (예방접종, 성향 등)

    var isApproved: Bool { status == .approved }
}
