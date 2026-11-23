import Foundation

/// 입력 칸 이름 (빠진 항목을 알려줄 때도 이 이름을 씁니다)
enum PetFormField: String, CaseIterable, Identifiable {
    case name = "이름"
    case breed = "견종"
    case vaccination = "예방접종"
    case neutered = "중성화 여부"
    case allergy = "알러지"
    case gender = "성별"
    case birthDate = "생년월일"
    case age = "연령"
    case health = "건강상태"
    case temperament = "성향"
    case animalRegistration = "동물등록 확인"

    var id: String { rawValue }

    /// 생년월일만 선택 사항이고, 나머지는 모두 필수
    var isRequired: Bool { self != .birthDate }
}

/// 반려견 정보 입력 중인 값. 모든 항목이 필수입니다.
struct PetFormState {
    var name = ""
    var breed = ""
    var vaccination: VaccinationStatus?
    var isNeutered: Bool?
    var allergy = ""
    var gender: PetGender?
    var birthDate: Date?
    var ageText = ""
    var healthCondition = ""
    var temperament = ""
    var isAnimalRegistered: Bool?

    private func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedName: String { clean(name) }
    var trimmedBreed: String { clean(breed) }

    /// 0~30살 사이의 숫자만 인정 (직접 기입)
    var age: Int? {
        guard let value = Int(clean(ageText)), (0...30).contains(value) else { return nil }
        return value
    }

    /// 아직 비어 있거나 올바르지 않은 항목
    var missingFields: [PetFormField] {
        var missing: [PetFormField] = []
        if clean(name).isEmpty { missing.append(.name) }
        if clean(breed).isEmpty { missing.append(.breed) }
        if vaccination == nil { missing.append(.vaccination) }
        if isNeutered == nil { missing.append(.neutered) }
        if clean(allergy).isEmpty { missing.append(.allergy) }
        if gender == nil { missing.append(.gender) }
        if age == nil { missing.append(.age) }
        if clean(healthCondition).isEmpty { missing.append(.health) }
        if clean(temperament).isEmpty { missing.append(.temperament) }
        if isAnimalRegistered == nil { missing.append(.animalRegistration) }
        return missing
    }

    var isComplete: Bool { missingFields.isEmpty }

    /// 모두 채워졌을 때만 상세 정보를 만들어 줍니다.
    func makeProfile() -> PetProfile? {
        guard isComplete,
              let vaccination, let isNeutered, let gender, let years = age,
              let isRegistered = isAnimalRegistered
        else { return nil }
        return PetProfile(
            vaccination: vaccination,
            isNeutered: isNeutered,
            allergy: clean(allergy),
            gender: gender,
            ageYears: years,
            birthDate: birthDate,
            healthCondition: clean(healthCondition),
            temperament: clean(temperament),
            isAnimalRegistered: isRegistered
        )
    }
}
