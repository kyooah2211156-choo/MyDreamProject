import Foundation
import Observation

/// 출석 기록 창고. 선생님이 등원·하원을 누르면 여기에 날짜별로 쌓여요.
@Observable
final class AttendanceStore {
    private let service: AttendanceService
    private(set) var entries: [AttendanceEntry] = []

    init(service: AttendanceService = FakeAttendanceService()) {
        self.service = service
        reload()
    }

    private func reload() { entries = service.load() }

    private var calendar: Calendar { Calendar.current }

    /// 한 강아지의 그날 기록
    func entry(petID: String, on day: Date) -> AttendanceEntry? {
        entries.first { $0.petID == petID && calendar.isDate($0.day, inSameDayAs: day) }
    }

    /// 등원 기록. 같은 날 이미 있으면 처음 등원한 시각을 두고, 하원을 되돌립니다.
    func recordCheckIn(petID: String, at time: Date = .now) {
        if var existing = entry(petID: petID, on: time) {
            existing.checkOut = nil
            service.save(existing)
        } else {
            service.save(AttendanceEntry(id: UUID().uuidString, petID: petID,
                                         day: calendar.startOfDay(for: time), checkIn: time, checkOut: nil))
        }
        reload()
    }

    /// 하원 기록
    func recordCheckOut(petID: String, at time: Date = .now) {
        guard var existing = entry(petID: petID, on: time) else { return }
        existing.checkOut = time
        service.save(existing)
        reload()
    }

    /// 강아지 한 마리의 기록 (최신순). petID가 nil이면 전체.
    func history(petID: String?) -> [AttendanceEntry] {
        entries.filter { petID == nil || $0.petID == petID }.sorted { $0.checkIn > $1.checkIn }
    }

    /// 한 달 안의 기록 (petIDs가 nil이면 전체)
    func entries(inMonth month: Date, petIDs: Set<String>?) -> [AttendanceEntry] {
        entries.filter {
            calendar.isDate($0.day, equalTo: month, toGranularity: .month)
                && (petIDs?.contains($0.petID) ?? true)
        }
    }

    /// 한 달 동안 강아지별로 며칠 왔는지
    func monthlyCounts(inMonth month: Date, petIDs: Set<String>?) -> [String: Int] {
        Dictionary(grouping: entries(inMonth: month, petIDs: petIDs), by: \.petID).mapValues(\.count)
    }
}
