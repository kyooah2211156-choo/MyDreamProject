import Foundation

/// 입학 필수 조건. 세 가지가 모두 확인돼야 최종 입학 승인을 할 수 있어요.
enum AdmissionCondition: String, CaseIterable, Identifiable, Hashable {
    case vaccination        // 예방접종 완료 (증명서 첨부 + 확인)
    case neutered           // 중성화 완료 확인
    case animalRegistration // 동물등록번호 확인

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vaccination: String(localized: "예방접종 완료")
        case .neutered: String(localized: "중성화 완료")
        case .animalRegistration: String(localized: "동물등록 완료")
        }
    }
}

/// 체험 후 적합성 판단
enum Suitability: String, Codable, CaseIterable, Hashable {
    case suitable       // 적합
    case conditional    // 조건부 적합 (훈련·관찰 필요)
    case unsuitable     // 부적합

    var displayName: String {
        switch self {
        case .suitable: String(localized: "적합")
        case .conditional: String(localized: "조건부 적합")
        case .unsuitable: String(localized: "부적합")
        }
    }
}

/// 무료 하루 체험 뒤에 남기는 성향·적합성 평가
struct TrialEvaluation: Codable, Hashable {
    var sociability: Int        // 사회성 1~5 (높을수록 좋아요)
    var energy: Int             // 활동량 1~5
    var anxiety: Int            // 불안·분리불안 1~5 (높을수록 심해요)
    var aggression: Int         // 공격성 1~5 (높을수록 심해요)
    var suitability: Suitability
    var comment: String
    var evaluatorID: String
    var date: Date
}

/// 입학 결정
enum AdmissionDecision: String, Codable, Hashable {
    case inProgress // 진행 중
    case admitted   // 입학 승인
    case declined   // 입학 불가

    var displayName: String {
        switch self {
        case .inProgress: String(localized: "입학 절차 진행 중")
        case .admitted: String(localized: "입학 승인")
        case .declined: String(localized: "입학 불가")
        }
    }
}

/// 반려견 한 마리의 입학 절차 기록
struct AdmissionRecord: Identifiable, Codable, Hashable {
    var petID: String
    var id: String { petID }

    var vaccinationCertificate: PhotoSource? = nil  // 예방접종 증명서 사진
    var vaccinationVerified = false                 // 직원이 증명서를 확인함
    var neuterConfirmed = false                     // 직원이 중성화 완료를 확인함
    var animalRegistrationNumber = ""               // 동물등록번호 (숫자 15자리)
    var registrationPhoto: PhotoSource? = nil       // 동물등록증(또는 내장칩 확인서) 사진. 번호 대신 사진으로도 인증할 수 있어요
    var registrationVerified = false                // 직원이 번호 또는 사진을 확인함
    var verifiedByID: String? = nil                 // 마지막으로 확인한 직원

    var evaluation: TrialEvaluation? = nil
    var decision: AdmissionDecision = .inProgress
    var decidedByID: String? = nil
    var decidedAt: Date? = nil
    var declineReason = ""

    /// 번호에서 숫자만 남긴 값
    static func digits(_ text: String) -> String { text.filter(\.isNumber) }

    /// 동물등록번호가 15자리 숫자인지
    var hasValidRegistrationNumber: Bool { Self.digits(animalRegistrationNumber).count == 15 }

    /// 번호(15자리) 또는 사진 중 하나라도 있으면 직원이 확인할 수 있어요.
    var hasRegistrationProof: Bool { hasValidRegistrationNumber || registrationPhoto != nil }

    func isMet(_ condition: AdmissionCondition) -> Bool {
        switch condition {
        case .vaccination: vaccinationCertificate != nil && vaccinationVerified
        case .neutered: neuterConfirmed
        case .animalRegistration: hasRegistrationProof && registrationVerified
        }
    }

    /// 아직 채우지 못한 필수 조건
    var missingConditions: [AdmissionCondition] {
        AdmissionCondition.allCases.filter { !isMet($0) }
    }

    var allConditionsMet: Bool { missingConditions.isEmpty }
}

extension AdmissionRecord {
    /// 이미 다니고 있는 샘플 반려견(보리·몽실·하늘)은 입학 절차를 마친 상태로 시작해요.
    static func samples() -> [AdmissionRecord] {
        ["pet-bori", "pet-mongsil", "pet-haneul"].enumerated().map { index, petID in
            AdmissionRecord(petID: petID,
                            vaccinationCertificate: .placeholder(symbol: "doc.text.fill", colorIndex: 0),
                            vaccinationVerified: true, neuterConfirmed: true,
                            animalRegistrationNumber: "410100000000" + String(format: "%03d", 101 + index),
                            registrationVerified: true, verifiedByID: SampleData.owner.id,
                            evaluation: TrialEvaluation(sociability: 4, energy: 4, anxiety: 2, aggression: 1,
                                                        suitability: .suitable, comment: "체험 때 잘 적응했어요.",
                                                        evaluatorID: SampleData.teacher.id, date: .now),
                            decision: .admitted, decidedByID: SampleData.owner.id, decidedAt: .now)
        }
    }
}
