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
        case .parent, .admin: false
        }
    }

    /// 댓글 작성: 모두 가능
    static func canComment(_ user: User) -> Bool { true }

    /// 선생님 초대 코드 만들기, 직원 퇴사 처리: 원장만
    static func canManageStaff(_ user: User) -> Bool { user.role == .owner }

    /// 원장 가입 승인/반려: 서비스 운영자만
    static func canApproveOwners(_ user: User) -> Bool { user.role == .admin }

    /// 건강 기록(응가·몸무게·식사량) 입력/수정/삭제: 원장, 선생님 (보호자는 내 반려견 기록 보기만)
    static func canEditHealthRecords(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 반려견 등록 신청: 운영자를 뺀 모든 역할
    static func canRequestPet(_ user: User) -> Bool { user.role != .admin }

    /// 훈련 진행도 기록: 원장, 선생님 (보호자는 내 반려견 것만 보기)
    static func canEditTrainingProgress(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 시간표 일정 추가/수정/삭제: 원장만 (선생님·보호자는 보기만)
    static func canEditSchedule(_ user: User) -> Bool { user.role == .owner }

    /// 반려견 등록 승인/반려: 원장, 선생님
    static func canReviewPets(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 사진글 보기: 원장·선생님은 전체, 보호자는 "내 승인된 반려견"이 태그된 글만
    static func canView(_ post: Post, by user: User, pets: [Pet]) -> Bool {
        switch user.role {
        case .owner, .teacher:
            return true
        case .admin:
            return false    // 운영자는 유치원 안의 사진·글을 볼 수 없어요
        case .parent:
            let myPetIDs = Set(pets.filter { $0.ownerID == user.id && $0.isApproved }.map(\.id))
            return !myPetIDs.isDisjoint(with: post.taggedPetIDs)
        }
    }
}
