import Foundation

/// 반려견 상세 정보와 맞춤 훈련을 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol PetDetailService {
    func loadDetails() -> [PetDetailInfo]
    func loadCustomTrainings() -> [CustomTraining]
    func loadPlans() -> [TrainingPlan]
    func save(detail: PetDetailInfo)
    func save(custom: CustomTraining)
    func deleteCustomTraining(id: String)
    func save(plan: TrainingPlan)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소
final class FakePetDetailService: PetDetailService {
    private var details = PetDetailInfo.samples()
    private var customs: [CustomTraining] = []
    private var plans = TrainingPlan.samples()

    func loadDetails() -> [PetDetailInfo] { details }
    func loadCustomTrainings() -> [CustomTraining] { customs }
    func loadPlans() -> [TrainingPlan] { plans }

    func save(detail: PetDetailInfo) {
        if let index = details.firstIndex(where: { $0.petID == detail.petID }) { details[index] = detail } else { details.append(detail) }
    }

    func save(custom: CustomTraining) {
        if let index = customs.firstIndex(where: { $0.id == custom.id }) { customs[index] = custom } else { customs.append(custom) }
    }

    func deleteCustomTraining(id: String) {
        customs.removeAll { $0.id == id }
        plans.removeAll { $0.trainingID == id }
    }

    func save(plan: TrainingPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) { plans[index] = plan } else { plans.append(plan) }
    }
}
