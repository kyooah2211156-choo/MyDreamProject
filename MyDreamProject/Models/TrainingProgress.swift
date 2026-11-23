import Foundation

/// 강아지 한 마리의 훈련 하나에 대한 그날의 진행도 기록
struct TrainingProgress: Identifiable, Codable, Hashable {
    let id: String
    var petID: String
    var trainingID: String
    var percent: Int            // 0~100, 10 단위
    var date: Date              // 그날 0시
    var memo: String            // 선택 메모 (없으면 빈 글자)
    var recordedByID: String
}

extension TrainingProgress {
    /// 샘플: 승인된 샘플 반려견 3마리의 훈련 진행 기록 (날짜별로 쌓인 모습)
    static func samples(today: Date = .now) -> [TrainingProgress] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let trainingIDs = ["training-sit", "training-wait", "training-hand",
                           "training-walk", "training-social", "training-recall"]
        // 반려견별로 훈련마다 지금 진행도
        let finals: [(petID: String, percents: [Int])] = [
            ("pet-bori", [90, 60, 50, 40, 20, 10]),
            ("pet-mongsil", [70, 50, 30, 20, 10, 0]),
            ("pet-haneul", [100, 80, 60, 50, 30, 20])
        ]
        var result: [TrainingProgress] = []
        for item in finals {
            for (index, trainingID) in trainingIDs.enumerated() {
                let final = item.percents[index]
                guard final > 0 else { continue }
                // 12일 전, 6일 전, 1일 전 순서로 조금씩 올라간 기록
                let steps: [(daysAgo: Int, percent: Int)] = [
                    (12, max(final - 40, 0)), (6, max(final - 20, 0)), (1, final)
                ]
                var seen = Set<Int>()
                for step in steps where step.percent > 0 && !seen.contains(step.percent) {
                    seen.insert(step.percent)
                    guard let day = calendar.date(byAdding: .day, value: -step.daysAgo, to: start) else { continue }
                    let isLatest = step.daysAgo == 1
                    result.append(TrainingProgress(
                        id: "sample-progress-\(item.petID)-\(trainingID)-\(step.daysAgo)",
                        petID: item.petID, trainingID: trainingID,
                        percent: step.percent, date: day,
                        memo: (isLatest && item.petID == "pet-bori" && trainingID == "training-sit")
                            ? String(localized: "간식 없이도 잘 앉아요") : "",
                        recordedByID: SampleData.teacher.id
                    ))
                }
            }
        }
        return result
    }
}
