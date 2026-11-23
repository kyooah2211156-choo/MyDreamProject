import Foundation
import Observation

/// 강아지별 훈련 진행도 데이터 창고. 한 강아지의 같은 훈련은 하루에 기록 하나만 있어요.
@Observable
final class TrainingProgressStore {
    private let service: TrainingProgressService
    private(set) var items: [TrainingProgress] = []

    init(service: TrainingProgressService = FakeTrainingProgressService()) {
        self.service = service
        reload()
    }

    private func reload() {
        items = service.load()
    }

    /// 한 강아지의 한 훈련 기록 (최신 날짜가 위)
    func history(petID: String, trainingID: String) -> [TrainingProgress] {
        items
            .filter { $0.petID == petID && $0.trainingID == trainingID }
            .sorted { $0.date > $1.date }
    }

    /// 지금 진행도(가장 최근 기록). 기록이 없으면 0
    func percent(petID: String, trainingID: String) -> Int {
        history(petID: petID, trainingID: trainingID).first?.percent ?? 0
    }

    /// 그날 기록
    func record(petID: String, trainingID: String, on day: Date) -> TrainingProgress? {
        let calendar = Calendar.current
        return history(petID: petID, trainingID: trainingID)
            .first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// 저장. 같은 날 기록이 있으면 그 기록을 고칩니다. (화면에서 권한을 먼저 확인한 뒤 호출)
    func save(_ progress: TrainingProgress) {
        var toSave = progress
        if let existing = record(petID: progress.petID, trainingID: progress.trainingID, on: progress.date),
           existing.id != progress.id {
            toSave = TrainingProgress(id: existing.id, petID: progress.petID, trainingID: progress.trainingID,
                                      percent: progress.percent, date: progress.date,
                                      memo: progress.memo, recordedByID: progress.recordedByID)
        }
        service.save(toSave)
        reload()
    }

    func delete(id: String) {
        service.delete(id: id)
        reload()
    }
}
