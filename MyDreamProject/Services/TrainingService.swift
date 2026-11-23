import Foundation

/// 훈련 목록을 불러오는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol TrainingService {
    func loadTrainings() -> [Training]
}

/// 연습용: 샘플 훈련을 돌려줍니다.
struct FakeTrainingService: TrainingService {
    func loadTrainings() -> [Training] { Training.samples }
}
