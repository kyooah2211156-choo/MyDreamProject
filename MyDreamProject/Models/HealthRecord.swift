import Foundation

/// 응가 상태
enum PoopStatus: String, Codable, CaseIterable, Hashable {
    case normal     // 정상
    case soft       // 묽음
    case diarrhea   // 설사
    case hard       // 단단함
    case bloody     // 혈변

    var displayName: String {
        switch self {
        case .normal: String(localized: "정상")
        case .soft: String(localized: "묽음")
        case .diarrhea: String(localized: "설사")
        case .hard: String(localized: "단단함")
        case .bloody: String(localized: "혈변")
        }
    }
}

/// 식욕 상태
enum AppetiteLevel: String, Codable, CaseIterable, Hashable {
    case good       // 좋음
    case normal     // 보통
    case poor       // 없음·부족

    var displayName: String {
        switch self {
        case .good: String(localized: "좋음")
        case .normal: String(localized: "보통")
        case .poor: String(localized: "부족")
        }
    }
}

/// 오늘의 컨디션
enum ConditionLevel: String, Codable, CaseIterable, Hashable {
    case great      // 아주 좋음
    case good       // 좋음
    case soso       // 보통
    case bad        // 안 좋음

    var displayName: String {
        switch self {
        case .great: String(localized: "아주 좋음")
        case .good: String(localized: "좋음")
        case .soso: String(localized: "보통")
        case .bad: String(localized: "안 좋음")
        }
    }
}

/// 건강 기록표의 한 칸: 강아지 한 마리의 하루 기록
/// (응가 횟수·상태, 소변 횟수, 몸무게, 식사량, 식욕, 구토, 컨디션, 특이사항)
/// 새 항목은 nil(또는 poopRecorded=false)이면 "기록 안 함"이고, 0회·0g은 "0이라고 기록함"이에요.
struct HealthRecord: Identifiable, Codable, Hashable {
    var id: String
    var petID: String
    var date: Date              // 그날 0시 (일자별로 나눠 보여줄 때 기준)
    var poopCount: Int          // 응가 횟수
    var weightKg: Double?       // 몸무게 (kg, 소수점 둘째 자리까지)
    var mealGrams: Int?         // 식사량 (g, 5 단위)
    var recordedByID: String
    var poopRecorded: Bool = true       // false면 응가 횟수를 기록하지 않은 것 (0회와 구분)
    var urineCount: Int? = nil          // 소변 횟수 (nil = 미기록)
    var poopStatus: PoopStatus? = nil   // 응가 상태 (nil = 미기록)
    var appetite: AppetiteLevel? = nil  // 식욕 (nil = 미기록)
    var vomited: Bool? = nil            // 구토 여부 (nil = 미기록)
    var condition: ConditionLevel? = nil    // 오늘의 컨디션 (nil = 미기록)
    var note: String = ""               // 건강 특이사항·비고
}

extension HealthRecord {
    /// 샘플: 최근 5일치. 오늘은 첫 번째 강아지만 기록해서 '기록 전' 모습도 볼 수 있어요.
    static func samples(today: Date = .now) -> [HealthRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let base: [(petID: String, weight: Double, meal: Int)] = [
            ("pet-bori", 4.2, 80),
            ("pet-mongsil", 5.8, 100),
            ("pet-haneul", 6.4, 110)
        ]
        var result: [HealthRecord] = []
        for offset in 0..<5 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { continue }
            for (index, item) in base.enumerated() {
                if offset == 0 && index > 0 { continue }
                let step = (offset + index) % 3
                result.append(HealthRecord(
                    id: "sample-health-\(offset)-\(item.petID)",
                    petID: item.petID,
                    date: day,
                    poopCount: step + 1,
                    weightKg: item.weight + Double(step) * 0.1,
                    mealGrams: item.meal + step * 5,
                    recordedByID: SampleData.teacher.id
                ))
            }
        }
        return result
    }
}
