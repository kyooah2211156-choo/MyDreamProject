import Foundation

/// 건강 기록을 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol HealthRecordService {
    func load() -> [HealthRecord]
    /// 같은 id가 있으면 덮어쓰고, 없으면 새로 추가합니다.
    func save(_ record: HealthRecord)
    func delete(id: String)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소 (최근 5일 샘플로 시작)
final class FakeHealthRecordService: HealthRecordService {
    private var records = HealthRecord.samples()

    func load() -> [HealthRecord] { records }

    func save(_ record: HealthRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    func delete(id: String) {
        records.removeAll { $0.id == id }
    }
}
