import Foundation

/// 알림장 작성 화면에서 입력 중인 건강 기록 값 (응가 횟수, 몸무게, 식사량)
struct HealthInputState: Equatable {
    var logPoop = false
    var poop = 0
    var logWeight = false
    var weightWhole = 5
    var weightTenth = 0
    var weightHundredth = 0
    var logMeal = false
    var mealGrams = 100

    init() {}

    /// 이미 기록이 있으면 그 값으로 채우고, 몸무게는 없으면 최근 몸무게(suggestedWeight)를 시작값으로 씁니다.
    init(record: HealthRecord?, suggestedWeight: Double?) {
        if let record {
            logPoop = true
            poop = record.poopCount
            if let weight = record.weightKg { logWeight = true; setWeight(weight) }
            if let meal = record.mealGrams { logMeal = true; mealGrams = min((meal / 5) * 5, 1000) }
        } else if let suggestedWeight {
            setWeight(suggestedWeight)
        }
    }

    /// 몸무게를 정수 / 소수 첫째 / 소수 둘째 자리로 나눠 담습니다. (예: 4.25 → 4, 2, 5)
    mutating func setWeight(_ weight: Double) {
        let total = min(max(Int((weight * 100).rounded()), 0), 9999)
        weightWhole = total / 100
        weightTenth = (total % 100) / 10
        weightHundredth = total % 10
    }

    var weightKg: Double {
        Double(weightWhole * 100 + weightTenth * 10 + weightHundredth) / 100
    }

    /// 하나라도 기록하겠다고 켜 두었는지
    var hasAnyInput: Bool { logPoop || logWeight || logMeal }

    /// 입력한 값을 건강 기록으로 만듭니다. 켜지 않은 항목은 기존 기록 값을 그대로 둡니다.
    /// 아무것도 켜지 않았으면 nil (기록을 만들지 않아요).
    func makeRecord(existing: HealthRecord?, petID: String, day: Date, recordedByID: String) -> HealthRecord? {
        guard hasAnyInput else { return nil }
        return HealthRecord(
            id: existing?.id ?? UUID().uuidString,
            petID: petID,
            date: Calendar.current.startOfDay(for: day),
            poopCount: logPoop ? poop : (existing?.poopCount ?? 0),
            weightKg: logWeight ? weightKg : existing?.weightKg,
            mealGrams: logMeal ? mealGrams : existing?.mealGrams,
            recordedByID: recordedByID
        )
    }
}
