import Foundation

/// 출석 기록을 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol AttendanceService {
    func load() -> [AttendanceEntry]
    /// 같은 id가 있으면 덮어쓰고, 없으면 새로 추가합니다.
    func save(_ entry: AttendanceEntry)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소 (샘플 출석으로 시작)
final class FakeAttendanceService: AttendanceService {
    private var entries = AttendanceEntry.samples()

    func load() -> [AttendanceEntry] { entries }

    func save(_ entry: AttendanceEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }
}
