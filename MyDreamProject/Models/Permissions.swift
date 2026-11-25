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

    /// 반려된 반려견을 직접 고쳐서 승인: 원장
    static func canEditAndApprovePets(_ user: User) -> Bool { user.role == .owner }

    /// 사진글 보기: 원장·선생님은 전체, 보호자는 "내 승인된 반려견"이 태그된 글만
    static func canView(_ post: Post, by user: User, pets: [Pet]) -> Bool {
        // 임시저장 글은 작성한 사람과 원장만 볼 수 있어요. (보호자에게는 공개 전까지 보이지 않아요)
        if !post.isPublished {
            return user.role == .owner || (user.role == .teacher && post.authorID == user.id)
        }
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

// MARK: - 경고 (원장·선생님이 기록하고, 정정과 이용 재개는 원장 확인으로만)

extension Permissions {
    /// 보호자 경고 기록: 원장, 선생님
    static func canIssueWarning(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 경고 차감(정정)과 이용 재개: 원장만
    static func canCorrectWarning(_ user: User) -> Bool { user.role == .owner }
}

// MARK: - 예약·상담

extension Permissions {
    /// 예약 신청·변경·취소: 보호자(본인 예약만)
    static func canBook(_ user: User) -> Bool { user.role == .parent }

    /// 예약 확정·완료 처리, 직원이 대신 변경·취소: 원장, 선생님
    static func canManageReservations(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 이 예약을 바꾸거나 취소할 수 있는지: 보호자는 본인 예약, 원장·선생님은 전체
    static func canModify(_ reservation: Reservation, by user: User) -> Bool {
        switch user.role {
        case .parent: reservation.parentID == user.id
        case .owner, .teacher: true
        case .admin: false
        }
    }

    /// 상담방 열람·전송: 참여한 보호자와 상대 직원만 (다른 직원도, 다른 보호자도 볼 수 없어요)
    static func canView(_ thread: ConsultThread, by user: User) -> Bool { thread.isParticipant(user.id) }
}

// MARK: - 신규 원생 입학 절차

extension Permissions {
    /// 증명서 첨부·등록번호 입력·체험 신청: 반려견의 보호자(원장·선생님도 대신 입력 가능)
    static func canSubmitAdmissionDocs(_ user: User, pet: Pet) -> Bool {
        switch user.role {
        case .parent: pet.ownerID == user.id
        case .owner, .teacher: true
        case .admin: false
        }
    }

    /// 증명서·중성화·동물등록 확인과 체험 후 평가: 원장, 선생님
    static func canVerifyAdmission(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 최종 입학 승인·불가: 원장만
    static func canDecideAdmission(_ user: User) -> Bool { user.role == .owner }
}

// MARK: - 반려견 상세 · 맞춤 훈련

extension Permissions {
    /// 이 반려견의 상세 페이지를 볼 수 있는지: 원장·선생님은 승인된 반려견 전체, 보호자는 내 반려견만
    static func canViewDetail(of pet: Pet, by user: User) -> Bool {
        switch user.role {
        case .owner, .teacher: pet.isApproved
        case .parent: pet.ownerID == user.id
        case .admin: false
        }
    }

    /// 연락처·약·급여 금지 음식 등 상세 정보 입력: 원장, 선생님, 반려견의 보호자
    static func canEditDetail(of pet: Pet, by user: User) -> Bool { canViewDetail(of: pet, by: user) }

    /// 공격성·분리불안 등 행동 특이사항 판단은 직원만 (보호자는 보기만)
    static func canEditBehavior(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }

    /// 반려견별 훈련 항목 추가·수정·삭제, 목표·담당 선생님·가정교육 안내 작성: 원장, 선생님
    static func canManageTrainingPlan(_ user: User) -> Bool { user.role == .owner || user.role == .teacher }
}

// MARK: - 운영·결제 (원장 / 선생님 / 보호자 / 운영자 구분)

extension Permissions {
    /// 이용권 남은 횟수·만료일 보기: 원장·선생님은 전체, 보호자는 내 반려견 것만 (운영자는 불가)
    static func canViewPasses(_ user: User) -> Bool { user.role != .admin }

    /// 이용권 등록·수정·삭제, 결제 내역 관리, 결제 완료 처리, 미납 알림: 원장만
    static func canManageBilling(_ user: User) -> Bool { user.role == .owner }

    /// 결제 내역·미결제 보기: 원장은 전체, 보호자는 내 것만. 선생님은 금액 정보를 볼 수 없어요.
    static func canViewPayments(_ user: User) -> Bool { user.role == .owner || user.role == .parent }

    /// 월별 출석 현황 보기: 원장·선생님은 전체, 보호자는 내 반려견만
    static func canViewAttendance(_ user: User) -> Bool { user.role != .admin }
}
