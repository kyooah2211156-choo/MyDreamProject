import Foundation

/// 강아지의 오늘 등원 상태
enum AttendanceStatus {
    case expected   // 등원 예정 (아직 안 옴)
    case present    // 등원함 (유치원에 있음)
    case departed   // 하원함 (집에 감)
}

/// 선생님 화면에서 쓰는 강아지 정보 (지금은 가상 데이터용)
struct Dog: Identifiable, Equatable {
    let id: UUID
    var name: String
    var breed: String
    var status: AttendanceStatus
    var checkInTime: Date?

    init(id: UUID = UUID(), name: String, breed: String,
         status: AttendanceStatus = .expected, checkInTime: Date? = nil) {
        self.id = id
        self.name = name
        self.breed = breed
        self.status = status
        self.checkInTime = checkInTime
    }
}

extension Dog {
    /// 미리보기용 가상 데이터
    static let samples: [Dog] = [
        Dog(name: "보리", breed: "말티즈", status: .present,
            checkInTime: Calendar.current.date(bySettingHour: 8, minute: 40, second: 0, of: .now)),
        Dog(name: "초코", breed: "푸들", status: .present,
            checkInTime: Calendar.current.date(bySettingHour: 9, minute: 5, second: 0, of: .now)),
        Dog(name: "콩이", breed: "포메라니안"),
        Dog(name: "몽실", breed: "비숑 프리제"),
        Dog(name: "하늘", breed: "시츄", status: .departed)
    ]
}
