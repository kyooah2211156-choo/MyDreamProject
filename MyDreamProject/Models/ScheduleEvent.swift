import Foundation

/// 시간표 일정의 종류
enum ScheduleKind: String, Codable, CaseIterable, Hashable {
    case program    // 프로그램
    case freeTime   // 자유시간
    case event      // 행사·안내
    case closed     // 휴원

    var displayName: String {
        switch self {
        case .program: String(localized: "프로그램")
        case .freeTime: String(localized: "자유시간")
        case .event: String(localized: "행사")
        case .closed: String(localized: "휴원")
        }
    }
}

/// 한 달 시간표에 들어가는 일정 한 건 (하루 안에 끝나는 일정)
struct ScheduleEvent: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var kind: ScheduleKind
    var start: Date
    var end: Date
    var isAllDay: Bool
    var note: String
}

extension ScheduleEvent {
    /// 이번 달 샘플 일정: 평일마다 오전 프로그램과 오후 자유시간, 행사 1건, 휴원 1건
    static func samples(around now: Date = .now) -> [ScheduleEvent] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return [] }

        func time(_ day: Date, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let programTitles = ["산책 프로그램", "기본 훈련", "사회화 놀이", "노즈워크", "목욕·위생 관리"]
        var result: [ScheduleEvent] = []
        var day = interval.start
        while day < interval.end {
            let number = calendar.component(.day, from: day)
            let weekday = calendar.component(.weekday, from: day)   // 1 = 일요일
            if number == 15 {
                result.append(ScheduleEvent(id: "sample-closed-\(number)", title: "전체 휴원", kind: .closed,
                                            start: calendar.startOfDay(for: day), end: calendar.startOfDay(for: day),
                                            isAllDay: true, note: "직원 교육이 있는 날이에요."))
            } else if (2...6).contains(weekday) {
                result.append(ScheduleEvent(id: "sample-program-\(number)", title: programTitles[weekday - 2],
                                            kind: .program, start: time(day, 10, 0), end: time(day, 11, 30),
                                            isAllDay: false, note: ""))
                result.append(ScheduleEvent(id: "sample-free-\(number)", title: "자유시간", kind: .freeTime,
                                            start: time(day, 14, 0), end: time(day, 15, 30),
                                            isAllDay: false, note: "마당에서 자유롭게 놀아요."))
            }
            if number == 10 {
                result.append(ScheduleEvent(id: "sample-event-\(number)", title: "예방접종 확인 안내", kind: .event,
                                            start: time(day, 16, 0), end: time(day, 17, 0),
                                            isAllDay: false, note: "접종 증명서를 가져와 주세요."))
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
        }
        return result
    }
}
