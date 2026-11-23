import Foundation

/// 서버가 없는 동안 쓰는 가짜 데이터. 나중에 서버 데이터로 교체합니다.
enum SampleData {
    // MARK: 사용자 (역할별 샘플 계정)

    static let owner = User(id: "user-owner", name: "김원장", role: .owner)
    static let teacher = User(id: "user-teacher", name: "이선생", role: .teacher)
    static let parent = User(id: "user-parent", name: "박보호", role: .parent)
    static let otherParent = User(id: "user-parent2", name: "최보호", role: .parent)

    static let users: [User] = [owner, teacher, parent, otherParent]

    // MARK: 반려견 (보호자 박보호: 대기중 1, 승인됨 1, 반려됨 1)

    static let petApproved = Pet(
        id: "pet-bori", name: "보리", breed: "말티즈",
        profilePhoto: .placeholder(symbol: "dog.fill", colorIndex: 0),
        ownerID: parent.id, status: .approved, rejectionReason: nil,
        requesterID: parent.id, reviewerID: teacher.id,
        profile: PetProfile(vaccination: .complete, isNeutered: true, allergy: "없음",
                            gender: .male, ageYears: 3, birthDate: yearsAgo(3), healthCondition: "건강해요", temperament: "활발하고 사람을 좋아해요",
                            isAnimalRegistered: true))

    static let petPending = Pet(
        id: "pet-choco", name: "초코", breed: "푸들",
        profilePhoto: .placeholder(symbol: "dog.fill", colorIndex: 1),
        ownerID: parent.id, status: .pending, rejectionReason: nil,
        requesterID: parent.id, reviewerID: nil,
        profile: PetProfile(vaccination: .partial, isNeutered: false, allergy: "닭고기",
                            gender: .female, ageYears: 1, birthDate: yearsAgo(1), healthCondition: "슬개골 관리 중이에요", temperament: "겁이 많지만 금방 친해져요"))

    static let petRejected = Pet(
        id: "pet-kong", name: "콩이", breed: "포메라니안",
        profilePhoto: nil,
        ownerID: parent.id, status: .rejected, rejectionReason: "프로필 사진이 없어요. 얼굴이 보이는 사진으로 다시 신청해 주세요.",
        requesterID: parent.id, reviewerID: owner.id,
        profile: PetProfile(vaccination: .notVaccinated, isNeutered: false, allergy: "없음",
                            gender: .female, ageYears: 5, healthCondition: "특별한 문제 없어요", temperament: "조용하고 차분해요"))

    // 다른 보호자의 승인된 반려견 (사진첩 필터와 권한 확인용)
    static let petOther1 = Pet(
        id: "pet-mongsil", name: "몽실", breed: "비숑 프리제",
        profilePhoto: .placeholder(symbol: "dog.fill", colorIndex: 2),
        ownerID: otherParent.id, status: .approved, rejectionReason: nil,
        requesterID: otherParent.id, reviewerID: owner.id,
        profile: PetProfile(vaccination: .complete, isNeutered: true, allergy: "없음",
                            gender: .male, ageYears: 2, birthDate: yearsAgo(2), healthCondition: "건강해요", temperament: "에너지가 넘쳐요"))

    static let petOther2 = Pet(
        id: "pet-haneul", name: "하늘", breed: "시츄",
        profilePhoto: .placeholder(symbol: "dog.fill", colorIndex: 3),
        ownerID: otherParent.id, status: .approved, rejectionReason: nil,
        requesterID: otherParent.id, reviewerID: teacher.id,
        profile: PetProfile(vaccination: .complete, isNeutered: true, allergy: "소고기",
                            gender: .female, ageYears: 4, birthDate: yearsAgo(4), healthCondition: "피부가 예민해요", temperament: "온순하고 친화적이에요",
                            isAnimalRegistered: true))

    static let pets: [Pet] = [petApproved, petPending, petRejected, petOther1, petOther2]

    // MARK: 공지

    static let notices: [Notice] = [
        Notice(id: "notice-1", authorID: owner.id,
               title: "이번 주 금요일은 단축 운영해요",
               content: "금요일은 직원 교육으로 오후 3시에 하원해요. 보호자님들께서 시간에 맞춰 데리러 와 주세요.",
               date: daysAgo(1)),
        Notice(id: "notice-2", authorID: owner.id,
               title: "예방접종 확인 안내",
               content: "종합백신 접종 증명서를 이번 달까지 제출해 주세요.",
               date: daysAgo(6))
    ]

    // MARK: 사진글

    static let posts: [Post] = [
        Post(id: "post-1", authorID: teacher.id,
             text: "오늘 보리와 몽실이가 공원에서 신나게 뛰어놀았어요!",
             photos: [photo("p1-1", "figure.run", 0), photo("p1-2", "tree.fill", 1),
                      photo("p1-3", "pawprint.fill", 2), photo("p1-4", "sun.max.fill", 3)],
             taggedPetIDs: [petApproved.id, petOther1.id],
             date: daysAgo(0), category: .program),
        Post(id: "post-2", authorID: owner.id,
             text: "간식 시간! 모두 앉아 기다리기 성공했어요.",
             photos: [photo("p2-1", "fork.knife", 1), photo("p2-2", "star.fill", 0)],
             taggedPetIDs: [petOther2.id],
             date: daysAgo(1), category: .program),
        Post(id: "post-3", authorID: teacher.id,
             text: "낮잠 시간에 보리가 제일 먼저 잠들었어요.",
             photos: [photo("p3-1", "moon.zzz.fill", 3), photo("p3-2", "bed.double.fill", 2),
                      photo("p3-3", "heart.fill", 0)],
             taggedPetIDs: [petApproved.id],
             date: daysAgo(3), category: .freeTime),
        // 영상 분류 샘플 (실제 영상 파일이 없어서 그림으로 대신 보여줘요)
        Post(id: "post-4", authorID: teacher.id,
             text: "신나게 달리는 영상이에요! 🐕",
             photos: [photo("p4-1", "play.rectangle.fill", 2), photo("p4-2", "play.rectangle.fill", 1)],
             taggedPetIDs: [petApproved.id],
             date: daysAgo(2), category: .video)
    ]

    // MARK: 댓글

    static let comments: [Comment] = [
        Comment(id: "comment-1", postID: "post-1", authorID: parent.id,
                content: "보리가 너무 즐거워 보여요! 감사합니다 😊", date: daysAgo(0)),
        Comment(id: "comment-2", postID: "post-1", authorID: teacher.id,
                content: "내일도 산책 나가요 🐾", date: daysAgo(0)),
        Comment(id: "comment-3", postID: "post-3", authorID: parent.id,
                content: "집에서도 잘 자요 ㅎㅎ", date: daysAgo(3))
    ]

    // MARK: 알림

    static let notifications: [AppNotification] = [
        AppNotification(id: "noti-1", recipientID: parent.id,
                        title: "반려견 등록이 승인됐어요",
                        content: "보리의 등록이 승인되었습니다.",
                        isRead: false, date: daysAgo(2)),
        AppNotification(id: "noti-2", recipientID: parent.id,
                        title: "반려견 등록이 반려됐어요",
                        content: "콩이의 등록이 반려되었습니다. 사유를 확인해 주세요.",
                        isRead: true, date: daysAgo(4)),
        AppNotification(id: "noti-3", recipientID: owner.id,
                        title: "새 반려견 등록 신청",
                        content: "박보호님이 초코의 등록을 신청했어요.",
                        isRead: false, date: daysAgo(0))
    ]

    // MARK: 도우미

    private static func photo(_ id: String, _ symbol: String, _ color: Int) -> PostPhoto {
        PostPhoto(id: id, source: .placeholder(symbol: symbol, colorIndex: color))
    }

    /// 몇 년 전 생일 (샘플 반려견 나이용)
    private static func yearsAgo(_ years: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -(years * 12 + 3), to: .now) ?? .now
    }

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
    }
}
