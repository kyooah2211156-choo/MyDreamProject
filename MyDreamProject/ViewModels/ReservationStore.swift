import Foundation
import Observation

/// 예약과 비공개 상담 창고. 권한에 맞게 걸러서 보여줍니다.
@Observable
final class ReservationStore {
    private let service: ReservationService
    private(set) var reservations: [Reservation] = []
    private(set) var threads: [ConsultThread] = []

    init(service: ReservationService = FakeReservationService()) {
        self.service = service
        reload()
    }

    private func reload() {
        reservations = service.loadReservations()
        threads = service.loadThreads()
    }

    private var calendar: Calendar { Calendar.current }

    // MARK: 예약 보기 (보호자는 내 예약만, 원장·선생님은 전체)

    func visibleReservations(for user: User) -> [Reservation] {
        let all: [Reservation]
        switch user.role {
        case .owner, .teacher: all = reservations
        case .parent: all = reservations.filter { $0.parentID == user.id }
        case .admin: all = []
        }
        return all.sorted { $0.start < $1.start }
    }

    func reservation(id: String) -> Reservation? { reservations.first { $0.id == id } }

    /// 그날의 (취소되지 않은) 예약
    func reservations(on day: Date, for user: User) -> [Reservation] {
        visibleReservations(for: user).filter { $0.status != .cancelled && calendar.isDate($0.start, inSameDayAs: day) }
    }

    /// 한 강아지·한 종류의 가장 최근 예약 (체험 예약 상태 확인에 씁니다)
    func latest(kind: ReservationKind, petID: String) -> Reservation? {
        reservations
            .filter { $0.kind == kind && $0.petID == petID && $0.status != .cancelled }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    // MARK: 예약 쓰기 (화면에서 권한을 먼저 확인한 뒤 호출)

    func save(_ reservation: Reservation) {
        var toSave = reservation
        toSave.updatedAt = .now
        service.save(reservation: toSave)
        reload()
    }

    func cancel(id: String, reason: String) {
        guard var reservation = reservation(id: id), reservation.isOpen else { return }
        reservation.status = .cancelled
        reservation.cancelReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        save(reservation)
    }

    func confirm(id: String, staffID: String) {
        guard var reservation = reservation(id: id), reservation.status == .requested else { return }
        reservation.status = .confirmed
        reservation.assignedStaffID = staffID
        save(reservation)
    }

    func complete(id: String) {
        guard var reservation = reservation(id: id), reservation.status == .confirmed else { return }
        reservation.status = .completed
        save(reservation)
    }

    // MARK: 비공개 1:1 상담

    /// 내가 참여한 상담방만 (참여하지 않은 직원·보호자에게는 보이지 않아요)
    func visibleThreads(for user: User) -> [ConsultThread] {
        threads.filter { $0.isParticipant(user.id) }.sorted { $0.lastDate > $1.lastDate }
    }

    func thread(id: String, for user: User) -> ConsultThread? {
        threads.first { $0.id == id && $0.isParticipant(user.id) }
    }

    /// 보호자가 새 상담을 시작합니다. 첫 메시지가 있어야 만들어져요.
    @discardableResult
    func startThread(parent: User, staffID: String, petID: String?, topic: String, firstMessage: String) -> ConsultThread? {
        let text = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard parent.role == .parent, !text.isEmpty, !cleanTopic.isEmpty else { return nil }
        let thread = ConsultThread(
            id: UUID().uuidString, parentID: parent.id, staffID: staffID, petID: petID, topic: cleanTopic,
            messages: [ConsultMessage(id: UUID().uuidString, authorID: parent.id, text: text, date: .now)])
        service.save(thread: thread)
        reload()
        return thread
    }

    /// 상담방 참여자만 메시지를 보낼 수 있어요.
    func send(threadID: String, from user: User, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, var thread = thread(id: threadID, for: user) else { return }
        thread.messages.append(ConsultMessage(id: UUID().uuidString, authorID: user.id, text: clean, date: .now))
        service.save(thread: thread)
        reload()
    }
}
