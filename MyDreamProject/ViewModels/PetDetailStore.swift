import Foundation
import Observation

/// 반려견 개인 상세 정보와 맞춤 훈련 계획 창고
@Observable
final class PetDetailStore {
    private let service: PetDetailService
    private(set) var details: [PetDetailInfo] = []
    private(set) var customTrainings: [CustomTraining] = []
    private(set) var plans: [TrainingPlan] = []

    init(service: PetDetailService = FakePetDetailService()) {
        self.service = service
        reload()
    }

    private func reload() {
        details = service.loadDetails()
        customTrainings = service.loadCustomTrainings()
        plans = service.loadPlans()
    }

    // MARK: 상세 정보

    func detail(petID: String) -> PetDetailInfo {
        details.first { $0.petID == petID } ?? PetDetailInfo(petID: petID)
    }

    func save(detail: PetDetailInfo) {
        service.save(detail: detail)
        reload()
    }

    // MARK: 맞춤 훈련 항목 (반려견별 추가·수정·삭제)

    func customTrainings(petID: String) -> [CustomTraining] {
        customTrainings.filter { $0.petID == petID }
    }

    func isCustom(trainingID: String) -> Bool { customTrainings.contains { $0.id == trainingID } }

    func customTraining(id: String) -> CustomTraining? { customTrainings.first { $0.id == id } }

    func save(custom: CustomTraining) {
        service.save(custom: custom)
        reload()
    }

    func deleteCustomTraining(id: String) {
        service.deleteCustomTraining(id: id)
        reload()
    }

    // MARK: 맞춤 계획 (목표·담당 선생님·가정교육 안내)

    func plan(petID: String, trainingID: String) -> TrainingPlan? {
        plans.first { $0.petID == petID && $0.trainingID == trainingID }
    }

    func save(plan: TrainingPlan) {
        service.save(plan: plan)
        reload()
    }
}
