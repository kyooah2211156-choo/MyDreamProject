import Foundation

/// 강아지별 훈련 진행도를 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol TrainingProgressService {
    func load() -> [TrainingProgress]
    /// 같은 id가 있으면 덮어쓰고, 없으면 새로 추가합니다.
    func save(_ progress: TrainingProgress)
    func delete(id: String)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소 (샘플 진행 기록으로 시작)
final class FakeTrainingProgressService: TrainingProgressService {
    private var items = TrainingProgress.samples()

    func load() -> [TrainingProgress] { items }

    func save(_ progress: TrainingProgress) {
        if let index = items.firstIndex(where: { $0.id == progress.id }) {
            items[index] = progress
        } else {
            items.append(progress)
        }
    }

    func delete(id: String) {
        items.removeAll { $0.id == id }
    }
}
