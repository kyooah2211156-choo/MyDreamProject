import Foundation

/// 예약과 상담 데이터를 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol ReservationService {
    func loadReservations() -> [Reservation]
    func loadThreads() -> [ConsultThread]
    func save(reservation: Reservation)
    func save(thread: ConsultThread)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소
final class FakeReservationService: ReservationService {
    private var reservations = Reservation.samples()
    private var threads = ConsultThread.samples()

    func loadReservations() -> [Reservation] { reservations }
    func loadThreads() -> [ConsultThread] { threads }

    func save(reservation: Reservation) {
        if let index = reservations.firstIndex(where: { $0.id == reservation.id }) {
            reservations[index] = reservation
        } else {
            reservations.append(reservation)
        }
    }

    func save(thread: ConsultThread) {
        if let index = threads.firstIndex(where: { $0.id == thread.id }) {
            threads[index] = thread
        } else {
            threads.append(thread)
        }
    }
}
