import Foundation

/// 시간표 일정을 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol ScheduleService {
    func load() -> [ScheduleEvent]
    /// 같은 id가 있으면 덮어쓰고, 없으면 새로 추가합니다.
    func save(_ event: ScheduleEvent)
    func delete(id: String)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 시간표 저장소 (이번 달 샘플로 시작)
final class FakeScheduleService: ScheduleService {
    private var events = ScheduleEvent.samples()

    func load() -> [ScheduleEvent] { events }

    func save(_ event: ScheduleEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
    }

    func delete(id: String) {
        events.removeAll { $0.id == id }
    }
}
