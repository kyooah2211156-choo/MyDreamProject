import Foundation
import Observation

/// 한 달 시간표 데이터 창고
@Observable
final class ScheduleStore {
    private let service: ScheduleService
    private(set) var events: [ScheduleEvent] = []

    init(service: ScheduleService = FakeScheduleService()) {
        self.service = service
        reload()
    }

    private func reload() {
        events = service.load()
    }

    /// 그날의 일정 (종일 일정이 먼저, 그다음 시작 시간순)
    func events(on day: Date) -> [ScheduleEvent] {
        let calendar = Calendar.current
        return events
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { first, second in
                if first.isAllDay != second.isAllDay { return first.isAllDay }
                return first.start < second.start
            }
    }

    /// 달력 칸에 점으로 보여줄 그날의 일정 종류 (중복 없이)
    func kinds(on day: Date) -> [ScheduleKind] {
        var seen: [ScheduleKind] = []
        for event in events(on: day) where !seen.contains(event.kind) {
            seen.append(event.kind)
        }
        return seen
    }

    /// 저장 (화면에서 권한을 먼저 확인한 뒤 호출)
    func save(_ event: ScheduleEvent) {
        service.save(event)
        reload()
    }

    func delete(id: String) {
        service.delete(id: id)
        reload()
    }
}
