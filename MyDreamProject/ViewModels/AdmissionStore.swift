import Foundation
import Observation

/// 신규 원생 입학 절차 창고: 증명서 첨부, 중성화·동물등록 확인, 체험 평가, 최종 입학 승인
@Observable
final class AdmissionStore {
    private let service: AdmissionService
    private(set) var records: [AdmissionRecord] = []

    init(service: AdmissionService = FakeAdmissionService()) {
        self.service = service
        reload()
    }

    private func reload() { records = service.load() }

    /// 반려견의 입학 기록. 아직 없으면 빈 기록(진행 중)이에요.
    func record(petID: String) -> AdmissionRecord {
        records.first { $0.petID == petID } ?? AdmissionRecord(petID: petID)
    }

    func isAdmitted(petID: String) -> Bool { record(petID: petID).decision == .admitted }

    private func update(petID: String, _ change: (inout AdmissionRecord) -> Void) {
        var record = record(petID: petID)
        change(&record)
        service.save(record)
        reload()
    }

    // MARK: 보호자·직원이 하는 일 (화면에서 권한을 먼저 확인한 뒤 호출)

    /// 예방접종 증명서 첨부. 새로 올리면 직원 확인이 다시 필요해요.
    func attachCertificate(petID: String, photo: PhotoSource) {
        update(petID: petID) {
            $0.vaccinationCertificate = photo
            $0.vaccinationVerified = false
        }
    }

    func removeCertificate(petID: String) {
        update(petID: petID) {
            $0.vaccinationCertificate = nil
            $0.vaccinationVerified = false
        }
    }

    /// 동물등록번호 입력. 바꾸면 직원 확인이 다시 필요해요.
    func setRegistrationNumber(petID: String, number: String) {
        update(petID: petID) {
            guard AdmissionRecord.digits($0.animalRegistrationNumber) != AdmissionRecord.digits(number) else { return }
            $0.animalRegistrationNumber = AdmissionRecord.digits(number)
            $0.registrationVerified = false
        }
    }

    // MARK: 직원 확인

    func verifyVaccination(petID: String, verified: Bool, staffID: String) {
        update(petID: petID) {
            guard $0.vaccinationCertificate != nil || !verified else { return }
            $0.vaccinationVerified = verified
            $0.verifiedByID = staffID
        }
    }

    func confirmNeutered(petID: String, confirmed: Bool, staffID: String) {
        update(petID: petID) {
            $0.neuterConfirmed = confirmed
            $0.verifiedByID = staffID
        }
    }

    func verifyRegistration(petID: String, verified: Bool, staffID: String) {
        update(petID: petID) {
            guard $0.hasValidRegistrationNumber || !verified else { return }
            $0.registrationVerified = verified
            $0.verifiedByID = staffID
        }
    }

    func saveEvaluation(petID: String, evaluation: TrialEvaluation) {
        update(petID: petID) { $0.evaluation = evaluation }
    }

    // MARK: 최종 결정 (원장)

    /// 최종 입학 승인이 가능한 이유가 모두 갖춰졌는지. 안 되면 못 하는 이유를 돌려줍니다.
    func approvalBlockers(petID: String, trialCompleted: Bool) -> [String] {
        let record = record(petID: petID)
        var blockers = record.missingConditions.map { String(localized: "\($0.title) 확인이 필요해요") }
        if !trialCompleted { blockers.append(String(localized: "무료 하루 체험을 마쳐야 해요")) }
        guard let evaluation = record.evaluation else {
            blockers.append(String(localized: "체험 후 적합성 평가가 필요해요"))
            return blockers
        }
        if evaluation.suitability == .unsuitable { blockers.append(String(localized: "평가가 '부적합'이라 승인할 수 없어요")) }
        return blockers
    }

    /// 최종 입학 승인. 조건이 모두 갖춰졌을 때만 됩니다.
    @discardableResult
    func approve(petID: String, trialCompleted: Bool, ownerID: String) -> Bool {
        guard approvalBlockers(petID: petID, trialCompleted: trialCompleted).isEmpty else { return false }
        update(petID: petID) {
            $0.decision = .admitted
            $0.decidedByID = ownerID
            $0.decidedAt = .now
            $0.declineReason = ""
        }
        return true
    }

    @discardableResult
    func decline(petID: String, reason: String, ownerID: String) -> Bool {
        let clean = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        update(petID: petID) {
            $0.decision = .declined
            $0.decidedByID = ownerID
            $0.decidedAt = .now
            $0.declineReason = clean
        }
        return true
    }
}
