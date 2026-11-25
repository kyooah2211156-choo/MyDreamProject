import Foundation
import Observation

/// 이용권과 결제 내역 창고. (테스트용: 실제 결제는 일어나지 않아요)
@Observable
final class BillingStore {
    private let service: BillingService
    private(set) var passes: [Pass] = []
    private(set) var payments: [Payment] = []

    init(service: BillingService = FakeBillingService()) {
        self.service = service
        reload()
    }

    private func reload() {
        passes = service.loadPasses()
        payments = service.loadPayments()
    }

    private var calendar: Calendar { Calendar.current }

    // MARK: 이용권

    /// 강아지의 이용권 (만료일이 가까운 것이 위)
    func passes(petID: String) -> [Pass] {
        passes.filter { $0.petID == petID }.sorted { $0.expiryDate < $1.expiryDate }
    }

    /// 지금 쓸 수 있는 이용권 중 만료가 가장 빠른 것
    func usablePass(petID: String, on day: Date = .now) -> Pass? {
        passes(petID: petID).first { $0.isUsable(on: day) }
    }

    /// 그날 이미 차감된 이용권이 있는지
    private func isConsumed(petID: String, on day: Date) -> Bool {
        passes(petID: petID).contains { pass in pass.usedDays.contains { calendar.isDate($0, inSameDayAs: day) } }
    }

    /// 등원했을 때 이용권을 한 번 차감합니다. 같은 날 다시 불러도 두 번 차감되지 않아요.
    /// 차감한 이용권을 돌려주고, 쓸 수 있는 이용권이 없으면 nil이에요.
    @discardableResult
    func consume(petID: String, on day: Date = .now) -> Pass? {
        guard !isConsumed(petID: petID, on: day), var pass = usablePass(petID: petID, on: day) else { return nil }
        pass.usedDays.append(calendar.startOfDay(for: day))
        service.save(pass: pass)
        reload()
        return pass
    }

    func save(pass: Pass) {
        service.save(pass: pass)
        reload()
    }

    func deletePass(id: String) {
        service.deletePass(id: id)
        reload()
    }

    // MARK: 결제

    func payments(petIDs: Set<String>?) -> [Payment] {
        payments.filter { petIDs?.contains($0.petID) ?? true }.sorted { $0.dueDate > $1.dueDate }
    }

    /// 미결제 내역 (기한이 오래된 것이 위)
    func unpaid(petIDs: Set<String>? = nil) -> [Payment] {
        payments.filter { $0.status == .unpaid && (petIDs?.contains($0.petID) ?? true) }.sorted { $0.dueDate < $1.dueDate }
    }

    func isOverdue(_ payment: Payment) -> Bool {
        payment.status == .unpaid && calendar.startOfDay(for: .now) > calendar.startOfDay(for: payment.dueDate)
    }

    func save(payment: Payment) {
        service.save(payment: payment)
        reload()
    }

    /// 결제 완료 처리 (테스트용 표시. 실제 결제는 하지 않아요)
    func markPaid(id: String, method: PaymentMethod) {
        guard var payment = payments.first(where: { $0.id == id }), payment.status == .unpaid else { return }
        payment.status = .paid
        payment.method = method
        payment.paidDate = .now
        service.save(payment: payment)
        reload()
    }

    func deletePayment(id: String) {
        service.deletePayment(id: id)
        reload()
    }
}
