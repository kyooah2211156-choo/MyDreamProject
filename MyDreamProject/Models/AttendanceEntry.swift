import Foundation

/// 강아지 한 마리의 하루 등원·하원 기록 (월별 출석 현황과 개인 등·하원 기록에 쓰여요)
struct AttendanceEntry: Identifiable, Codable, Hashable {
    let id: String
    var petID: String
    var day: Date               // 그날 0시
    var checkIn: Date           // 등원한 시각
    var checkOut: Date?         // 하원한 시각 (아직 있으면 nil)
}

extension AttendanceEntry {
    /// 샘플: 최근 60일 중 평일 대부분 (반려견마다 오는 요일이 조금씩 달라요). 오늘은 비워 둬서 등원 버튼을 직접 눌러 볼 수 있어요.
    static func samples(today: Date = .now) -> [AttendanceEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let pets = ["pet-bori", "pet-mongsil", "pet-haneul"]
        var result: [AttendanceEntry] = []
        for offset in 1...60 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: day)   // 1 = 일요일
            guard (2...6).contains(weekday) else { continue }
            for (index, petID) in pets.enumerated() {
                // 보리는 매일, 몽실은 월·수·금, 하늘은 화·목에 와요.
                let comes: Bool
                switch index {
                case 0: comes = true
                case 1: comes = [2, 4, 6].contains(weekday)
                default: comes = [3, 5].contains(weekday)
                }
                guard comes else { continue }
                let inTime = calendar.date(bySettingHour: 8 + (offset + index) % 2, minute: 30 + (offset % 3) * 10, second: 0, of: day) ?? day
                let outTime = calendar.date(bySettingHour: 17 + (offset + index) % 2, minute: 10, second: 0, of: day)
                result.append(AttendanceEntry(id: "sample-attend-\(offset)-\(petID)", petID: petID,
                                              day: day, checkIn: inTime, checkOut: outTime))
            }
        }
        return result
    }
}
