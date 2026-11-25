import Foundation
import Observation

/// 건강 기록 데이터 창고. 한 강아지의 같은 날 기록은 하나만 있어요.
@Observable
final class HealthRecordStore {
    private let service: HealthRecordService
    private(set) var records: [HealthRecord] = []

    init(service: HealthRecordService = FakeHealthRecordService()) {
        self.service = service
        reload()
    }

    private func reload() {
        records = service.load()
    }

    /// 한 강아지의 그날 기록
    func record(petID: String, on day: Date) -> HealthRecord? {
        let calendar = Calendar.current
        return records.first { $0.petID == petID && calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// 가장 최근에 기록한 몸무게 (몸무게를 처음 고를 때 시작값으로 씁니다)
    func latestWeight(petID: String) -> Double? {
        records
            .filter { $0.petID == petID && $0.weightKg != nil }
            .sorted { $0.date > $1.date }
            .first?.weightKg
    }

    /// 저장. 같은 강아지·같은 날 기록이 있으면 그 기록을 고칩니다. (화면에서 권한을 먼저 확인한 뒤 호출)
    func save(_ record: HealthRecord) {
        var toSave = record
        if let existing = self.record(petID: record.petID, on: record.date), existing.id != record.id {
            toSave = record
            toSave.id = existing.id
        }
        service.save(toSave)
        reload()
    }

    func delete(id: String) {
        service.delete(id: id)
        reload()
    }
}
