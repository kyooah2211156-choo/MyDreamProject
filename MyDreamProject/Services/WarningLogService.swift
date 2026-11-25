import Foundation

/// 보호자 경고 이력을 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol WarningLogService {
    func load() -> [WarningRecord]
    func add(_ record: WarningRecord)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소
final class FakeWarningLogService: WarningLogService {
    private var records: [WarningRecord] = []

    func load() -> [WarningRecord] { records }
    func add(_ record: WarningRecord) { records.append(record) }
}
