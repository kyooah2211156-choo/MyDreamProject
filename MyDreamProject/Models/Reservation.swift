import Foundation

/// 예약 종류
enum ReservationKind: String, Codable, CaseIterable, Hashable {
    case daycare            // 유치원 이용 예약
    case trainingConsult    // 훈련 상담 예약
    case pickup             // 픽업 (집 → 유치원)
    case dropoff            // 드롭 (유치원 → 집)
    case trial              // 무료 하루 체험

    var displayName: String {
        switch self {
        case .daycare: String(localized: "유치원 이용")
        case .trainingConsult: String(localized: "훈련 상담")
        case .pickup: String(localized: "픽업")
        case .dropoff: String(localized: "드롭")
        case .trial: String(localized: "무료 하루 체험")
        }
    }

    var symbol: String {
        switch self {
        case .daycare: "house.fill"
        case .trainingConsult: "bubble.left.and.bubble.right.fill"
        case .pickup: "car.fill"
        case .dropoff: "arrow.uturn.backward.circle.fill"
        case .trial: "gift.fill"
        }
    }

    /// 입학 승인을 받은 반려견만 예약할 수 있는 종류
    var requiresAdmission: Bool {
        switch self {
        case .daycare, .pickup, .dropoff: true
        case .trainingConsult, .trial: false
        }
    }

    /// 장소(주소)를 적어야 하는 종류
    var needsAddress: Bool { self == .pickup || self == .dropoff }
}

/// 예약 상태
enum ReservationStatus: String, Codable, CaseIterable, Hashable {
    case requested  // 신청함 (확정 전)
    case confirmed  // 확정
    case cancelled  // 취소
    case completed  // 완료

    var displayName: String {
        switch self {
        case .requested: String(localized: "확정 대기")
        case .confirmed: String(localized: "확정")
        case .cancelled: String(localized: "취소")
        case .completed: String(localized: "완료")
        }
    }
}

/// 예약 한 건
struct Reservation: Identifiable, Codable, Hashable {
    let id: String
    var kind: ReservationKind
    var petID: String
    var parentID: String
    var start: Date
    var status: ReservationStatus
    var note: String = ""
    var address: String = ""            // 픽업·드롭 장소
    var assignedStaffID: String? = nil  // 확정한 원장·담당 선생님
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var cancelReason: String = ""

    /// 아직 진행할 수 있는 예약 (취소·완료가 아니고, 시간이 지나지 않음)
    var isOpen: Bool { status == .requested || status == .confirmed }
}

extension Reservation {
    /// 샘플 예약: 보호자 박보호의 이용 예약·상담, 몽실 보호자의 픽업
    static func samples(today: Date = .now) -> [Reservation] {
        let calendar = Calendar.current
        func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today)) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        return [
            Reservation(id: "resv-1", kind: .daycare, petID: "pet-bori", parentID: SampleData.parent.id,
                        start: at(1, 9), status: .confirmed, note: "하루 종일 이용해요.",
                        assignedStaffID: SampleData.teacher.id),
            Reservation(id: "resv-2", kind: .trainingConsult, petID: "pet-bori", parentID: SampleData.parent.id,
                        start: at(3, 15), status: .requested, note: "산책 예절 상담을 받고 싶어요."),
            Reservation(id: "resv-3", kind: .pickup, petID: "pet-mongsil", parentID: SampleData.otherParent.id,
                        start: at(2, 8, 30), status: .requested, note: "", address: "서울시 마포구 샘플로 12"),
            Reservation(id: "resv-4", kind: .trial, petID: "pet-choco", parentID: SampleData.parent.id,
                        start: at(4, 10), status: .confirmed, note: "첫 체험이에요.",
                        assignedStaffID: SampleData.teacher.id)
        ]
    }
}

/// 보호자와 원장·담당 선생님 사이의 비공개 1:1 상담 메시지
struct ConsultMessage: Identifiable, Codable, Hashable {
    let id: String
    var authorID: String
    var text: String
    var date: Date
}

/// 비공개 1:1 상담방. 참여한 보호자와 원장(또는 담당 선생님) 두 사람만 볼 수 있어요.
struct ConsultThread: Identifiable, Codable, Hashable {
    let id: String
    var parentID: String
    var staffID: String             // 상담 상대 (원장 또는 담당 선생님)
    var petID: String?
    var topic: String
    var messages: [ConsultMessage]
    var createdAt: Date = .now

    var participantIDs: [String] { [parentID, staffID] }
    func isParticipant(_ userID: String) -> Bool { participantIDs.contains(userID) }
    var lastDate: Date { messages.last?.date ?? createdAt }
}

extension ConsultThread {
    static func samples(today: Date = .now) -> [ConsultThread] {
        let calendar = Calendar.current
        func ago(_ hours: Int) -> Date { calendar.date(byAdding: .hour, value: -hours, to: today) ?? today }
        return [
            ConsultThread(id: "consult-1", parentID: SampleData.parent.id, staffID: SampleData.teacher.id,
                          petID: "pet-bori", topic: "분리불안 상담",
                          messages: [
                            ConsultMessage(id: "cm-1", authorID: SampleData.parent.id,
                                           text: "집에 혼자 있을 때 계속 짖어요. 유치원에서는 어떤가요?", date: ago(30)),
                            ConsultMessage(id: "cm-2", authorID: SampleData.teacher.id,
                                           text: "유치원에서는 처음 30분만 불안해하고 금방 안정돼요. 가정에서 연습하는 방법을 알려 드릴게요.", date: ago(28))
                          ], createdAt: ago(30))
        ]
    }
}
