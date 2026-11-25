import Foundation

/// 건강 기록의 새 항목(소변·응가 상태·식욕·구토·컨디션·특이사항) 입력 중인 값.
/// 항목마다 "기록하기" 스위치를 켜야 기록돼요. 끄면 '미기록'이고, 켠 뒤 0회로 두면 '0회'로 기록돼요.
struct HealthExtraInput: Equatable {
    var logUrine = false
    var urine = 0
    var logPoopStatus = false
    var poopStatus: PoopStatus = .normal
    var logAppetite = false
    var appetite: AppetiteLevel = .normal
    var logVomit = false
    var vomited = false
    var logCondition = false
    var condition: ConditionLevel = .good
    var note = ""

    init() {}

    /// 이미 있는 기록 값으로 채웁니다.
    init(record: HealthRecord?) {
        guard let record else { return }
        if let urine = record.urineCount { logUrine = true; self.urine = urine }
        if let status = record.poopStatus { logPoopStatus = true; poopStatus = status }
        if let appetite = record.appetite { logAppetite = true; self.appetite = appetite }
        if let vomited = record.vomited { logVomit = true; self.vomited = vomited }
        if let condition = record.condition { logCondition = true; self.condition = condition }
        note = record.note
    }

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 하나라도 기록하겠다고 켜 두었거나 비고를 적었는지
    var hasAnyInput: Bool {
        logUrine || logPoopStatus || logAppetite || logVomit || logCondition || !trimmedNote.isEmpty
    }

    /// 입력한 값을 기록에 옮깁니다.
    /// keepExisting이 true면 켜지 않은 항목은 기존 값을 그대로 두고, false면 끈 항목을 '미기록'으로 되돌려요.
    func apply(to record: inout HealthRecord, keepExisting: Bool) {
        if logUrine { record.urineCount = urine } else if !keepExisting { record.urineCount = nil }
        if logPoopStatus { record.poopStatus = poopStatus } else if !keepExisting { record.poopStatus = nil }
        if logAppetite { record.appetite = appetite } else if !keepExisting { record.appetite = nil }
        if logVomit { record.vomited = vomited } else if !keepExisting { record.vomited = nil }
        if logCondition { record.condition = condition } else if !keepExisting { record.condition = nil }
        if !trimmedNote.isEmpty || !keepExisting { record.note = trimmedNote }
    }
}
