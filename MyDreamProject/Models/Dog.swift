import Foundation

/// 강아지의 오늘 등원 상태
enum AttendanceStatus {
    case expected   // 등원 예정 (아직 안 옴)
    case present    // 등원함 (유치원에 있음)
    case departed   // 하원함 (집에 감)
}

/// 선생님 화면에서 쓰는 등원·하원용 강아지 정보.
/// petID가 있으면 승인된 반려견과 같은 아이예요. (건강 기록 등을 이어서 열 수 있어요)
struct Dog: Identifiable, Equatable {
    let id: UUID
    var name: String
    var breed: String
    var status: AttendanceStatus
    var checkInTime: Date?
    var petID: String?

    init(id: UUID = UUID(), name: String, breed: String,
         status: AttendanceStatus = .expected, checkInTime: Date? = nil, petID: String? = nil) {
        self.id = id
        self.name = name
        self.breed = breed
        self.status = status
        self.checkInTime = checkInTime
        self.petID = petID
    }
}

extension Dog {
    /// 미리보기용 가상 데이터 (승인된 샘플 반려견과 같은 아이들)
    static let samples: [Dog] = [
        Dog(name: "보리", breed: "말티즈", status: .present,
            checkInTime: Calendar.current.date(bySettingHour: 8, minute: 40, second: 0, of: .now),
            petID: "pet-bori"),
        Dog(name: "몽실", breed: "비숑 프리제", petID: "pet-mongsil"),
        Dog(name: "하늘", breed: "시츄", status: .departed, petID: "pet-haneul")
    ]
}
