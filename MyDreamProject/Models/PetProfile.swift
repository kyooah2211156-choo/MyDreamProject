import Foundation

/// 예방접종 상태
enum VaccinationStatus: String, Codable, CaseIterable, Hashable {
    case complete       // 접종 완료
    case partial        // 일부 접종
    case notVaccinated  // 미접종

    var displayName: String {
        switch self {
        case .complete: "접종 완료"
        case .partial: "일부 접종"
        case .notVaccinated: "미접종"
        }
    }
}

/// 반려견 성별
enum PetGender: String, Codable, CaseIterable, Hashable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: "수컷"
        case .female: "암컷"
        }
    }
}

/// 보호자 가입(반려견 등록) 때 반드시 적는 반려견 상세 정보
struct PetProfile: Codable, Hashable {
    var vaccination: VaccinationStatus
    var isNeutered: Bool            // 중성화 여부
    var allergy: String             // 알러지 (보호자가 직접 기입, 없으면 "없음")
    var gender: PetGender
    var ageYears: Int               // 연령 (살) - 보호자가 직접 기입
    var birthDate: Date? = nil      // 생년월일 (선택)
    var healthCondition: String     // 건강상태
    var temperament: String         // 성향
    var isAnimalRegistered: Bool = false    // 동물등록(등록번호) 확인 여부. 나머지는 원장이 직접 확인

    /// 생년월일로 계산한 만 나이(살). 연령 칸을 채워 줄 때만 씁니다.
    static func years(from birthDate: Date, to now: Date = .now) -> Int {
        max(Calendar.current.dateComponents([.year], from: birthDate, to: now).year ?? 0, 0)
    }
}
