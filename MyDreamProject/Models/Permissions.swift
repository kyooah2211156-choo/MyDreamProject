import Foundation

/// 권한표를 코드로 옮긴 곳. "누가 무엇을 할 수 있는지"는 전부 여기서 정합니다.
enum Permissions {
    /// 공지 작성/수정/삭제: 원장만
    static func canWriteNotice(_ user: User) -> Bool { user.role == .owner }
    static func canEdit(_ notice: Notice, by user: User) -> Bool { user.role == .owner }

    /// 반려견 사진+글 올리기: 원장, 선생님
    static func canWritePost(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 사진글 수정·삭제: 원장은 전체, 선생님은 본인이 올린 것만, 보호자는 불가
    static func canEdit(_ post: Post, by user: User) -> Bool {
        switch user.role {
        case .owner: true
        case .teacher: post.authorID == user.id
        case .parent: false
        }
    }

    /// 댓글 작성: 모두 가능
    static func canComment(_ user: User) -> Bool { true }

    /// 반려견 등록 승인/반려: 원장, 선생님
    static func canReviewPets(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 사진글 보기: 원장·선생님은 전체, 보호자는 "내 승인된 반려견"이 태그된 글만
    static func canView(_ post: Post, by user: User, pets: [Pet]) -> Bool {
        switch user.role {
        case .owner, .teacher:
            return true
        case .parent:
            let myPetIDs = Set(pets.filter { $0.ownerID == user.id && $0.isApproved }.map(\.id))
            return !myPetIDs.isDisjoint(with: post.taggedPetIDs)
        }
    }
}
