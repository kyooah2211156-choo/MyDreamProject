import Foundation

/// 이용권 한 장 (횟수권). 등원하면 그날 한 번 차감돼요. 실제 결제와는 연결되지 않은 테스트용이에요.
struct Pass: Identifiable, Codable, Hashable {
    let id: String
    var petID: String
    var title: String
    var totalCount: Int
    var usedDays: [Date] = []       // 차감된 날짜 (같은 날은 한 번만)
    var startDate: Date
    var expiryDate: Date            // 이 날까지 쓸 수 있어요
    var createdByID: String

    var usedCount: Int { usedDays.count }
    var remainingCount: Int { max(totalCount - usedCount, 0) }

    func isExpired(on day: Date = .now) -> Bool {
        Calendar.current.startOfDay(for: day) > Calendar.current.startOfDay(for: expiryDate)
    }

    /// 지금 쓸 수 있는지 (남은 횟수가 있고 만료 전)
    func isUsable(on day: Date = .now) -> Bool { remainingCount > 0 && !isExpired(on: day) }

    /// 만료까지 남은 날 수 (오늘 만료면 0, 지났으면 음수)
    func daysUntilExpiry(from day: Date = .now) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: day),
                                       to: calendar.startOfDay(for: expiryDate)).day ?? 0
    }
}

/// 결제 상태
enum PaymentStatus: String, Codable, CaseIterable, Hashable {
    case unpaid     // 미결제
    case paid       // 결제 완료

    var displayName: String {
        switch self {
        case .unpaid: String(localized: "미결제")
        case .paid: String(localized: "결제 완료")
        }
    }
}

/// 결제 수단 (테스트용 표시일 뿐 실제 결제는 일어나지 않아요)
enum PaymentMethod: String, Codable, CaseIterable, Hashable {
    case card
    case transfer
    case cash

    var displayName: String {
        switch self {
        case .card: String(localized: "카드")
        case .transfer: String(localized: "계좌이체")
        case .cash: String(localized: "현금")
        }
    }
}

/// 결제 내역 한 건
struct Payment: Identifiable, Codable, Hashable {
    let id: String
    var petID: String
    var parentID: String
    var title: String
    var amount: Int                 // 원
    var status: PaymentStatus
    var dueDate: Date               // 결제 기한
    var paidDate: Date? = nil
    var method: PaymentMethod? = nil
    var passID: String? = nil       // 이 결제로 등록된 이용권
    var memo: String = ""
    var createdByID: String
}

extension Pass {
    /// 샘플 이용권: 보리(여유), 몽실(곧 만료), 하늘(횟수 거의 소진)
    static func samples(today: Date = .now) -> [Pass] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: start) ?? start }
        func used(_ count: Int, from entries: [AttendanceEntry]) -> [Date] {
            Array(entries.sorted { $0.day < $1.day }.prefix(count).map(\.day))
        }
        let attendance = AttendanceEntry.samples(today: today)
        func days(_ petID: String, _ count: Int) -> [Date] { used(count, from: attendance.filter { $0.petID == petID }) }
        return [
            Pass(id: "pass-bori", petID: "pet-bori", title: "20회권", totalCount: 20,
                 usedDays: days("pet-bori", 8), startDate: day(-40), expiryDate: day(50), createdByID: SampleData.owner.id),
            Pass(id: "pass-mongsil", petID: "pet-mongsil", title: "10회권", totalCount: 10,
                 usedDays: days("pet-mongsil", 6), startDate: day(-30), expiryDate: day(5), createdByID: SampleData.owner.id),
            Pass(id: "pass-haneul", petID: "pet-haneul", title: "10회권", totalCount: 10,
                 usedDays: days("pet-haneul", 9), startDate: day(-45), expiryDate: day(20), createdByID: SampleData.owner.id)
        ]
    }
}

extension Payment {
    /// 샘플 결제 내역: 이용권마다 결제 완료 1건, 하늘은 미결제 1건 추가
    static func samples(today: Date = .now) -> [Payment] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: start) ?? start }
        return [
            Payment(id: "pay-bori", petID: "pet-bori", parentID: SampleData.parent.id, title: "20회권",
                    amount: 400_000, status: .paid, dueDate: day(-40), paidDate: day(-40), method: .card,
                    passID: "pass-bori", createdByID: SampleData.owner.id),
            Payment(id: "pay-mongsil", petID: "pet-mongsil", parentID: SampleData.otherParent.id, title: "10회권",
                    amount: 220_000, status: .paid, dueDate: day(-30), paidDate: day(-29), method: .transfer,
                    passID: "pass-mongsil", createdByID: SampleData.owner.id),
            Payment(id: "pay-haneul", petID: "pet-haneul", parentID: SampleData.otherParent.id, title: "10회권",
                    amount: 220_000, status: .paid, dueDate: day(-45), paidDate: day(-45), method: .card,
                    passID: "pass-haneul", createdByID: SampleData.owner.id),
            Payment(id: "pay-haneul-next", petID: "pet-haneul", parentID: SampleData.otherParent.id, title: "10회권 (다음 이용권)",
                    amount: 220_000, status: .unpaid, dueDate: day(-2), createdByID: SampleData.owner.id)
        ]
    }
}
