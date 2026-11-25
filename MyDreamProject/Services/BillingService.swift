import Foundation

/// 이용권과 결제 내역을 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
/// 지금은 실제 결제 시스템과 연결하지 않은 테스트용이에요.
protocol BillingService {
    func loadPasses() -> [Pass]
    func loadPayments() -> [Payment]
    func save(pass: Pass)
    func deletePass(id: String)
    func save(payment: Payment)
    func deletePayment(id: String)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소
final class FakeBillingService: BillingService {
    private var passes = Pass.samples()
    private var payments = Payment.samples()

    func loadPasses() -> [Pass] { passes }
    func loadPayments() -> [Payment] { payments }

    func save(pass: Pass) {
        if let index = passes.firstIndex(where: { $0.id == pass.id }) { passes[index] = pass } else { passes.append(pass) }
    }

    func deletePass(id: String) { passes.removeAll { $0.id == id } }

    func save(payment: Payment) {
        if let index = payments.firstIndex(where: { $0.id == payment.id }) { payments[index] = payment } else { payments.append(payment) }
    }

    func deletePayment(id: String) { payments.removeAll { $0.id == id } }
}
