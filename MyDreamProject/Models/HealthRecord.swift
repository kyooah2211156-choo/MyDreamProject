import Foundation

/// 건강 기록표의 한 칸: 강아지 한 마리의 하루 기록 (응가 횟수, 몸무게, 식사량)
struct HealthRecord: Identifiable, Codable, Hashable {
    let id: String
    var petID: String
    var date: Date              // 그날 0시 (일자별로 나눠 보여줄 때 기준)
    var poopCount: Int          // 응가 횟수
    var weightKg: Double?       // 몸무게 (kg, 소수점 둘째 자리까지)
    var mealGrams: Int?         // 식사량 (g, 5 단위)
    var recordedByID: String
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
