import Foundation

/// 훈련 난이도
enum TrainingDifficulty: String, Codable, CaseIterable, Hashable {
    case beginner
    case intermediate
    case advanced

    var displayName: String {
        switch self {
        case .beginner: String(localized: "초급")
        case .intermediate: String(localized: "중급")
        case .advanced: String(localized: "고급")
        }
    }
}

/// 훈련 한 가지 (목록 카드와 상세 화면에 쓰입니다)
struct Training: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var summary: String
    var difficulty: TrainingDifficulty
    var steps: [String]
    var tip: String
    var symbol: String          // SF Symbols 그림 이름
}

extension Training {
    /// 샘플 훈련 목록 (서버가 생기면 서버 데이터로 교체)
    static let samples: [Training] = [
        Training(id: "training-sit", title: String(localized: "앉아"), summary: String(localized: "간식을 보여 주면 엉덩이를 바닥에 붙여요."),
                 difficulty: .beginner,
                 steps: [String(localized: "간식을 코 앞에 보여 줘요"), String(localized: "천천히 머리 위로 올려요"), String(localized: "엉덩이가 닿으면 '앉아'라고 말하고 칭찬해요")],
                 tip: String(localized: "성공하는 순간 바로 칭찬해야 무엇을 잘했는지 알아요."),
                 symbol: "figure.seated.side"),
        Training(id: "training-wait", title: String(localized: "기다려"), summary: String(localized: "신호가 있을 때까지 가만히 기다려요."),
                 difficulty: .beginner,
                 steps: [String(localized: "'앉아' 상태에서 손바닥을 보여 줘요"), String(localized: "'기다려'라고 말하고 한 걸음 물러나요"), String(localized: "1~2초 뒤 돌아와 간식을 줘요")],
                 tip: String(localized: "처음에는 아주 짧게 시작하고 조금씩 시간을 늘려요."),
                 symbol: "timer"),
        Training(id: "training-hand", title: String(localized: "손"), summary: String(localized: "앞발을 내 손 위에 올려요."),
                 difficulty: .beginner,
                 steps: [String(localized: "'앉아' 상태에서 손을 내밀어요"), String(localized: "앞발이 닿으면 '손'이라고 말해요"), String(localized: "바로 칭찬하고 간식을 줘요")],
                 tip: String(localized: "발을 억지로 잡지 말고 스스로 올리게 기다려 주세요."),
                 symbol: "hand.raised.fill"),
        Training(id: "training-walk", title: String(localized: "산책 예절"), summary: String(localized: "줄이 팽팽해지지 않게 옆에서 걸어요."),
                 difficulty: .intermediate,
                 steps: [String(localized: "줄이 느슨할 때 칭찬해요"), String(localized: "당기면 멈춰서 기다려요"), String(localized: "줄이 느슨해지면 다시 걸어요")],
                 tip: String(localized: "짧은 거리에서 성공 경험을 쌓은 뒤 거리를 늘려요."),
                 symbol: "figure.walk"),
        Training(id: "training-social", title: String(localized: "사회화 훈련"), summary: String(localized: "다른 강아지와 사람에게 차분하게 인사해요."),
                 difficulty: .intermediate,
                 steps: [String(localized: "멀리서 서로 보게 해요"), String(localized: "차분하면 칭찬하고 간식을 줘요"), String(localized: "천천히 거리를 좁혀 인사해요")],
                 tip: String(localized: "겁먹은 모습이 보이면 거리를 다시 벌려 주세요."),
                 symbol: "person.2.fill"),
        Training(id: "training-recall", title: String(localized: "부르면 오기"), summary: String(localized: "이름을 부르면 바로 달려와요."),
                 difficulty: .advanced,
                 steps: [String(localized: "실내에서 이름을 부르고 간식으로 불러요"), String(localized: "거리를 조금씩 늘려요"), String(localized: "산만한 곳에서도 연습해요")],
                 tip: String(localized: "불렀는데 왔을 때는 항상 좋은 일이 생겨야 해요."),
                 symbol: "megaphone.fill")
    ]
}
