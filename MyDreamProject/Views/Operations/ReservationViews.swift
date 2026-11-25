import SwiftUI

/// 예약 목록: 보호자는 내 예약을 신청·변경·취소하고, 원장·선생님은 전체 예약을 확정·완료·변경·취소해요.
struct ReservationSheet: View {
    var initialPetID: String? = nil

    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(ReservationStore.self) private var reservations
    @Environment(NotificationStore.self) private var notifications
    @State private var editorMode: ReservationEditorMode?
    @State private var cancelTarget: Reservation?
    @State private var showsPast = false

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, user.role != .admin {
                    content(user)
                } else {
                    Text("볼 수 없는 화면이에요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("예약")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CloseButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if let user = session.currentUser, Permissions.canBook(user) {
                        Button { editorMode = .create(petID: initialPetID) } label: {
                            Image(systemName: "plus").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("예약 신청")
                    }
                }
            }
            .sheet(item: $editorMode) { mode in ReservationEditorView(mode: mode) }
            .confirmationDialog("예약을 취소할까요?", isPresented: Binding(
                get: { cancelTarget != nil }, set: { if !$0 { cancelTarget = nil } }
            ), titleVisibility: .visible, presenting: cancelTarget) { target in
                Button("예약 취소", role: .destructive) { cancel(target) }
            } message: { target in
                Text("\(target.kind.displayName) · \(target.start.formatted(date: .abbreviated, time: .shortened))")
            }
        }
    }

    private func content(_ user: User) -> some View {
        let all = reservations.visibleReservations(for: user)
        let upcoming = all.filter { $0.isOpen && $0.start >= Calendar.current.startOfDay(for: .now) }
        let past = all.filter { !(upcoming.contains($0)) }.sorted { $0.start > $1.start }
        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                if user.role == .parent {
                    Text("유치원 이용, 훈련 상담, 픽업·드롭을 예약해요. 이용·픽업·드롭은 입학이 승인된 반려견만 예약할 수 있어요.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
                OpsSectionTitle(text: "다가오는 예약")
                if upcoming.isEmpty { OpsEmptyCard(text: "다가오는 예약이 없어요") }
                ForEach(upcoming) { card($0, user: user) }

                Button {
                    withAnimation { showsPast.toggle() }
                } label: {
                    HStack {
                        Text("지난·취소된 예약 \(past.count)").font(AppTheme.Typography.headline)
                        Image(systemName: "chevron.down").rotationEffect(.degrees(showsPast ? 0 : -90))
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.text)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                if showsPast { ForEach(past) { card($0, user: user) } }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func card(_ reservation: Reservation, user: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(reservation.kind.displayName, systemImage: reservation.kind.symbol)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                ReservationStatusPill(status: reservation.status)
            }
            Text("\(notebook.petName(reservation.petID)) · \(reservation.start.formatted(date: .abbreviated, time: .shortened))")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.text)
            if user.role != .parent {
                Text("보호자 \(notebook.authorName(reservation.parentID))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            if !reservation.address.isEmpty {
                Label(reservation.address, systemImage: "mappin.and.ellipse")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            if !reservation.note.isEmpty {
                Text(reservation.note).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
            }
            if let staffID = reservation.assignedStaffID {
                Text("담당 \(notebook.authorName(staffID))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            if reservation.status == .cancelled, !reservation.cancelReason.isEmpty {
                Text("취소 사유: \(reservation.cancelReason)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.statusRejected)
            }
            if reservation.isOpen, Permissions.canModify(reservation, by: user) {
                actions(reservation, user: user)
            }
        }
        .opsCard()
    }

    private func actions(_ reservation: Reservation, user: User) -> some View {
        HStack(spacing: 8) {
            if Permissions.canManageReservations(user) {
                if reservation.status == .requested {
                    Button("확정") { confirm(reservation, user: user) }.buttonStyle(AnyButtonStyle.gradient)
                } else {
                    Button("완료") { complete(reservation) }.buttonStyle(AnyButtonStyle.gradient)
                }
            }
            Button("변경") { editorMode = .edit(reservation) }.buttonStyle(AnyButtonStyle.soft)
            Button("취소") { cancelTarget = reservation }.buttonStyle(AnyButtonStyle.soft)
        }
    }

    // MARK: 처리 (상대방에게 앱 안 알림이 가요)

    private func confirm(_ reservation: Reservation, user: User) {
        guard Permissions.canManageReservations(user) else { return }
        reservations.confirm(id: reservation.id, staffID: user.id)
        notifications.send(to: reservation.parentID, title: String(localized: "예약이 확정됐어요"),
                           content: String(localized: "\(reservation.kind.displayName) · \(reservation.start.formatted(date: .abbreviated, time: .shortened)) 예약이 확정됐어요."))
    }

    private func complete(_ reservation: Reservation) {
        guard let user = session.currentUser, Permissions.canManageReservations(user) else { return }
        reservations.complete(id: reservation.id)
    }

    private func cancel(_ reservation: Reservation) {
        guard let user = session.currentUser, Permissions.canModify(reservation, by: user) else { return }
        reservations.cancel(id: reservation.id,
                            reason: user.role == .parent ? String(localized: "보호자가 취소했어요") : String(localized: "유치원에서 취소했어요"))
        let text = String(localized: "\(reservation.kind.displayName) · \(reservation.start.formatted(date: .abbreviated, time: .shortened)) 예약이 취소됐어요.")
        if user.role == .parent {
            ReservationNotifier.toStaff(notebook: notebook, notifications: notifications,
                                        title: String(localized: "예약이 취소됐어요"), content: text)
        } else {
            notifications.send(to: reservation.parentID, title: String(localized: "예약이 취소됐어요"), content: text)
        }
        cancelTarget = nil
    }
}

/// 보호자가 예약을 신청·변경하면 원장님께 알려요.
enum ReservationNotifier {
    static func toStaff(notebook: NotebookStore, notifications: NotificationStore, title: String, content: String) {
        for owner in notebook.staffUsers where owner.role == .owner {
            notifications.send(to: owner.id, title: title, content: content)
        }
    }
}

enum ReservationEditorMode: Identifiable {
    case create(petID: String?)
    case edit(Reservation)

    var id: String {
        switch self {
        case .create(let petID): "create-\(petID ?? "none")"
        case .edit(let reservation): "edit-\(reservation.id)"
        }
    }
}

/// 예약 신청·변경 창
struct ReservationEditorView: View {
    let mode: ReservationEditorMode

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(AdmissionStore.self) private var admission
    @Environment(ReservationStore.self) private var reservations
    @Environment(NotificationStore.self) private var notifications
    @State private var kind: ReservationKind
    @State private var petID: String?
    @State private var start: Date
    @State private var address: String
    @State private var note: String
    @State private var errorMessage: String?

    init(mode: ReservationEditorMode) {
        self.mode = mode
        switch mode {
        case .create(let petID):
            _kind = State(initialValue: .daycare)
            _petID = State(initialValue: petID)
            _start = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0,
                                                              of: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now) ?? .now)
            _address = State(initialValue: "")
            _note = State(initialValue: "")
        case .edit(let reservation):
            _kind = State(initialValue: reservation.kind)
            _petID = State(initialValue: reservation.petID)
            _start = State(initialValue: reservation.start)
            _address = State(initialValue: reservation.address)
            _note = State(initialValue: reservation.note)
        }
    }

    private var editing: Reservation? {
        if case .edit(let reservation) = mode { return reservation }
        return nil
    }

    /// 새 예약에서 고를 수 있는 종류 (무료 체험은 입학 절차 화면에서 예약해요)
    private var selectableKinds: [ReservationKind] { ReservationKind.allCases.filter { $0 != .trial } }

    private var pets: [Pet] {
        guard let user = session.currentUser else { return [] }
        return notebook.opsPets(for: user).filter { $0.status != .rejected }
    }

    private var selectedPetID: String? { petID ?? pets.first?.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if editing == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            OpsSectionTitle(text: "예약 종류")
                            ChoiceChips(options: selectableKinds, selection: $kind) { $0.displayName }
                        }
                        .opsCard()
                    } else {
                        Label(kind.displayName, systemImage: kind.symbol)
                            .font(AppTheme.Typography.title)
                            .foregroundStyle(AppTheme.text)
                    }
                    if editing == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            OpsSectionTitle(text: "반려견")
                            if pets.isEmpty {
                                Text("예약할 수 있는 반려견이 없어요")
                                    .font(AppTheme.Typography.body).foregroundStyle(AppTheme.subText)
                            } else {
                                OpsPetChips(pets: pets, selectedID: $petID)
                            }
                        }
                        .opsCard()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "날짜와 시간")
                        DatePicker("날짜와 시간", selection: $start, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.graphical)
                    }
                    .opsCard()
                    if kind.needsAddress {
                        VStack(alignment: .leading, spacing: 10) {
                            OpsSectionTitle(text: kind == .pickup ? "픽업 장소" : "드롭 장소")
                            OpsField(placeholder: "주소를 적어 주세요", text: $address)
                        }
                        .opsCard()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "요청 사항")
                        OpsField(placeholder: "전달할 내용 (선택)", text: $note, multiline: true)
                    }
                    .opsCard()
                    if let errorMessage {
                        Text(errorMessage).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.statusRejected)
                    }
                    Button(editing == nil ? "예약 신청" : "변경 저장", action: save)
                        .buttonStyle(GradientButtonStyle())
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(editing == nil ? "예약 신청" : "예약 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }

    private func save() {
        guard let user = session.currentUser else { return }
        guard let petID = selectedPetID else {
            errorMessage = String(localized: "반려견을 골라 주세요.")
            return
        }
        if let editing {
            guard Permissions.canModify(editing, by: user), editing.isOpen else { return }
        } else {
            guard Permissions.canBook(user) else { return }
        }
        guard start > .now else {
            errorMessage = String(localized: "지금보다 이후 시간을 골라 주세요.")
            return
        }
        if kind.needsAddress && address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = String(localized: "장소를 적어 주세요.")
            return
        }
        if kind.requiresAdmission && !admission.isAdmitted(petID: petID) {
            errorMessage = String(localized: "입학이 승인된 반려견만 예약할 수 있어요. 입학 절차를 먼저 마쳐 주세요.")
            return
        }
        let calendar = Calendar.current
        let sameDay = reservations.reservations.contains {
            $0.id != editing?.id && $0.petID == petID && $0.kind == kind && $0.isOpen
                && calendar.isDate($0.start, inSameDayAs: start)
        }
        if sameDay {
            errorMessage = String(localized: "같은 날 같은 종류의 예약이 이미 있어요.")
            return
        }
        let cleanAddress = kind.needsAddress ? address.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let petName = notebook.petName(petID)
        if var updated = editing {
            updated.start = start
            updated.address = cleanAddress
            updated.note = cleanNote
            // 시간이 바뀌면 보호자가 바꾼 경우 다시 확정을 받아요.
            if user.role == .parent { updated.status = .requested; updated.assignedStaffID = nil }
            reservations.save(updated)
            let text = String(localized: "\(petName)의 \(kind.displayName) 예약이 \(start.formatted(date: .abbreviated, time: .shortened))로 변경됐어요.")
            if user.role == .parent {
                ReservationNotifier.toStaff(notebook: notebook, notifications: notifications,
                                            title: String(localized: "예약이 변경됐어요"), content: text)
            } else {
                notifications.send(to: updated.parentID, title: String(localized: "예약이 변경됐어요"), content: text)
            }
        } else {
            reservations.save(Reservation(id: UUID().uuidString, kind: kind, petID: petID, parentID: user.id,
                                          start: start, status: .requested, note: cleanNote, address: cleanAddress))
            ReservationNotifier.toStaff(notebook: notebook, notifications: notifications,
                                        title: String(localized: "새 예약 신청"),
                                        content: String(localized: "\(user.name)님이 \(petName)의 \(kind.displayName) 예약을 신청했어요."))
        }
        dismiss()
    }
}

// MARK: - 비공개 1:1 상담

/// 보호자와 원장·담당 선생님만 볼 수 있는 비공개 상담 목록
struct ConsultListSheet: View {
    var initialPetID: String? = nil

    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(ReservationStore.self) private var reservations
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, user.role != .admin {
                    list(user)
                } else {
                    Text("볼 수 없는 화면이에요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("1:1 상담")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CloseButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if let user = session.currentUser, Permissions.canBook(user) {
                        Button { showingNew = true } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }
                            .accessibilityLabel("새 상담")
                    }
                }
            }
            .sheet(isPresented: $showingNew) { NewConsultSheet(initialPetID: initialPetID) }
        }
    }

    private func list(_ user: User) -> some View {
        let threads = reservations.visibleThreads(for: user)
        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Label("상담 내용은 대화에 참여한 두 사람만 볼 수 있어요.", systemImage: "lock.fill")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                if threads.isEmpty { OpsEmptyCard(text: "진행 중인 상담이 없어요") }
                ForEach(threads) { thread in
                    NavigationLink {
                        ConsultThreadView(threadID: thread.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(thread.topic).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.text)
                                Spacer()
                                Text(thread.lastDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTheme.Typography.caption2).foregroundStyle(AppTheme.subText)
                            }
                            let other = user.id == thread.parentID ? thread.staffID : thread.parentID
                            Text("\(notebook.authorName(other))\(thread.petID.map { " · " + notebook.petName($0) } ?? "")")
                                .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
                            Text(thread.messages.last?.text ?? "")
                                .font(AppTheme.Typography.body).foregroundStyle(AppTheme.text).lineLimit(1)
                        }
                        .opsCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

/// 상담 대화방
struct ConsultThreadView: View {
    let threadID: String

    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(ReservationStore.self) private var reservations
    @Environment(NotificationStore.self) private var notifications
    @State private var text = ""

    var body: some View {
        if let user = session.currentUser, let thread = reservations.thread(id: threadID, for: user) {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(thread.messages) { message in bubble(message, mine: message.authorID == user.id) }
                    }
                    .padding(AppTheme.Spacing.large)
                }
                HStack(spacing: 8) {
                    TextField("메시지를 입력해 주세요", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(AppTheme.text)
                    Button { send(thread, user: user) } label: {
                        Image(systemName: "paperplane.fill").frame(width: 44, height: 44)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("보내기")
                    .foregroundStyle(AppTheme.softButtonText)
                }
                .padding(AppTheme.Spacing.medium)
                .background(.bar)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(thread.topic)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            OpsEmptyCard(text: "이 상담은 볼 수 없어요").padding()
        }
    }

    private func bubble(_ message: ConsultMessage, mine: Bool) -> some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            Text(notebook.authorName(message.authorID))
                .font(AppTheme.Typography.caption2).foregroundStyle(AppTheme.subText)
            Text(message.text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(mine ? AppTheme.buttonText : AppTheme.text)
                .padding(12)
                .background(mine ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.card),
                            in: RoundedRectangle(cornerRadius: 16))
            Text(message.date.formatted(date: .omitted, time: .shortened))
                .font(AppTheme.Typography.caption2).foregroundStyle(AppTheme.subText)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private func send(_ thread: ConsultThread, user: User) {
        guard Permissions.canView(thread, by: user) else { return }
        reservations.send(threadID: thread.id, from: user, text: text)
        let other = user.id == thread.parentID ? thread.staffID : thread.parentID
        notifications.send(to: other, title: String(localized: "새 상담 메시지"),
                           content: String(localized: "\(user.name)님이 '\(thread.topic)' 상담에 메시지를 보냈어요."))
        text = ""
    }
}

/// 보호자가 원장 또는 담당 선생님을 골라 새 상담을 시작하는 창
struct NewConsultSheet: View {
    var initialPetID: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(ReservationStore.self) private var reservations
    @Environment(NotificationStore.self) private var notifications
    @State private var staffID: String?
    @State private var petID: String?
    @State private var topic = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "상담할 사람")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(notebook.staffUsers) { staff in
                                    let isOn = (staffID ?? notebook.staffUsers.first?.id) == staff.id
                                    Button { staffID = staff.id } label: {
                                        Text("\(staff.name) \(staff.role.displayName)")
                                            .font(AppTheme.Typography.headline)
                                            .padding(.horizontal, 16).frame(minHeight: 44)
                                            .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                                            .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Text("선택한 사람과 나만 볼 수 있는 비공개 상담이에요.")
                            .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
                    }
                    .opsCard()
                    if let user = session.currentUser {
                        let pets = notebook.opsPets(for: user)
                        if !pets.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                OpsSectionTitle(text: "반려견")
                                OpsPetChips(pets: pets, selectedID: Binding(
                                    get: { petID ?? initialPetID }, set: { petID = $0 }))
                            }
                            .opsCard()
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "상담 주제")
                        OpsField(placeholder: "예: 산책 훈련 상담", text: $topic)
                        OpsField(placeholder: "첫 메시지", text: $message, multiline: true)
                    }
                    .opsCard()
                    Button("상담 시작", action: start)
                        .buttonStyle(GradientButtonStyle())
                        .disabled(topic.trimmingCharacters(in: .whitespaces).isEmpty
                                  || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("새 상담")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }

    private func start() {
        guard let user = session.currentUser, Permissions.canBook(user),
              let staff = staffID ?? notebook.staffUsers.first?.id else { return }
        let thread = reservations.startThread(parent: user, staffID: staff, petID: petID ?? initialPetID,
                                              topic: topic, firstMessage: message)
        if thread != nil {
            notifications.send(to: staff, title: String(localized: "새 상담 요청"),
                               content: String(localized: "\(user.name)님이 '\(topic)' 상담을 시작했어요."))
            dismiss()
        }
    }
}
