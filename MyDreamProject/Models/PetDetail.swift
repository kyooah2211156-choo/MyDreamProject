import Foundation

/// 복용 중인 약 한 가지
struct PetMedication: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var dosage: String      // 용량·횟수 (예: 하루 2번, 한 알)
    var note: String        // 급여 시 주의사항
}

/// 반려견 개인 상세 페이지에 쓰는 추가 정보 (등록 때 적은 정보 말고 더 필요한 것들)
struct PetDetailInfo: Identifiable, Codable, Hashable {
    var petID: String
    var id: String { petID }

    var guardianPhone = ""          // 보호자 연락처
    var emergencyName = ""          // 비상 연락처 이름·관계
    var emergencyPhone = ""         // 비상 연락처 번호
    var forbiddenFoods = ""         // 급여 금지 음식 (알레르기는 등록 정보에 있어요)
    var medications: [PetMedication] = []
    var illnessHistory = ""         // 기존 질병
    var surgeryHistory = ""         // 수술 이력
    var isAggressive = false        // 공격성
    var hasSeparationAnxiety = false    // 분리불안
    var behaviorNote = ""           // 그 밖의 특이사항

    /// 주의가 필요한 특이사항이 있는지 (목록·등원 화면에서 표시할 때 씁니다)
    var hasBehaviorAlert: Bool { isAggressive || hasSeparationAnxiety }
}

extension PetDetailInfo {
    static func samples() -> [PetDetailInfo] {
        [
            PetDetailInfo(petID: "pet-bori", guardianPhone: "010-1234-5678",
                          emergencyName: "박가족 (어머니)", emergencyPhone: "010-2222-3333",
                          forbiddenFoods: "초콜릿, 포도",
                          medications: [PetMedication(id: "med-1", name: "관절 영양제", dosage: "하루 1번, 한 알", note: "식사 후 급여")],
                          illnessHistory: "알레르기성 피부염 (2년 전)", surgeryHistory: "중성화 수술 (1년 전)",
                          hasSeparationAnxiety: true, behaviorNote: "보호자와 헤어질 때 30분 정도 불안해해요."),
            PetDetailInfo(petID: "pet-mongsil", guardianPhone: "010-5555-6666",
                          emergencyName: "최가족 (남편)", emergencyPhone: "010-7777-8888",
                          forbiddenFoods: "양파", isAggressive: false, behaviorNote: "에너지가 많아 충분한 산책이 필요해요."),
            PetDetailInfo(petID: "pet-haneul", guardianPhone: "010-5555-6666",
                          emergencyName: "최가족 (남편)", emergencyPhone: "010-7777-8888",
                          forbiddenFoods: "소고기 간식 전부",
                          medications: [PetMedication(id: "med-2", name: "피부 연고", dosage: "하루 2번", note: "귀 뒤쪽에 얇게")],
                          illnessHistory: "피부염", isAggressive: true, behaviorNote: "다른 강아지가 갑자기 다가오면 으르렁거려요.")
        ]
    }
}

/// 반려견별로 따로 추가한 훈련 항목 (기본 훈련 목록과 따로 이 강아지에게만 보여요)
struct CustomTraining: Identifiable, Codable, Hashable {
    let id: String
    var petID: String
    var title: String
    var summary: String
    var difficulty: TrainingDifficulty
    var steps: [String]
    var tip: String
    var symbol: String = "star.fill"

    /// 기존 훈련 화면에서 그대로 쓸 수 있는 모양으로 바꿔요.
    var asTraining: Training {
        Training(id: id, title: title, summary: summary, difficulty: difficulty,
                 steps: steps, tip: tip, symbol: symbol)
    }
}

/// 강아지 한 마리의 훈련 하나에 대한 맞춤 계획: 목표, 담당 선생님, 가정교육 안내
struct TrainingPlan: Identifiable, Codable, Hashable {
    var petID: String
    var trainingID: String
    var id: String { petID + "|" + trainingID }

    var goalPercent: Int = 100          // 목표 진행률 (10 단위)
    var goalNote = ""                   // 목표 설명 (예: 산책 중 줄 당기지 않기)
    var targetDate: Date? = nil         // 목표 날짜
    var teacherID: String? = nil        // 담당 선생님
    var homeGuide = ""                  // 보호자에게 알려 주는 가정교육 방법
}

extension TrainingPlan {
    static func samples(today: Date = .now) -> [TrainingPlan] {
        let target = Calendar.current.date(byAdding: .day, value: 30, to: today)
        return [
            TrainingPlan(petID: "pet-bori", trainingID: "training-walk", goalPercent: 80,
                         goalNote: "산책 중 줄이 팽팽해지지 않고 옆에서 걷기", targetDate: target,
                         teacherID: SampleData.teacher.id,
                         homeGuide: "집 앞에서 5분만 연습해요. 줄이 느슨할 때마다 바로 칭찬하고 간식을 주세요."),
            TrainingPlan(petID: "pet-bori", trainingID: "training-sit", goalPercent: 100,
                         goalNote: "간식 없이 손짓만으로 앉기", teacherID: SampleData.teacher.id,
                         homeGuide: "식사 전에 '앉아'를 한 번 시키고 그릇을 내려놓아요.")
        ]
    }
}
