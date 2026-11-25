import SwiftUI

/// 이용권 · 결제 내역 · 미결제 관리 (테스트용: 실제 결제와 연결되지 않아요)
/// - 원장: 모두 관리 / 선생님: 이용권 남은 횟수·만료일만 보기 / 보호자: 내 반려견 것만 보기
struct BillingSheet: View {
    private enum Tab: CaseIterable {
        case passes, payments, unpaid

        var title: String {
            switch self {
            case .passes: String(localized: "이용권")
            case .payments: String(localized: "결제 내역")
            case .unpaid: String(localized: "미결제")
            }
        }
    }

    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(BillingStore.self) private var billing
    @Environment(NotificationStore.self) private var notifications
    @State private var tab: Tab = .passes
    @State private var passEditor: PassEditorMode?
    @State private var showingPaymentEditor = false
    @State private var payTarget: Payment?
    @State private var deletePassTarget: Pass?

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canViewPasses(user) {
                    content(user)
                } else {
                    Text("볼 수 없는 화면이에요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("이용권 · 결제")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CloseButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if let user = session.currentUser, Permissions.canManageBilling(user) {
                        Menu {
                            Button("이용권 등록", systemImage: "ticket") { passEditor = .create }
                            Button("결제 내역 추가", systemImage: "creditcard") { showingPaymentEditor = true }
                        } label: {
                            Image(systemName: "plus").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("추가")
                    }
                }
            }
            .sheet(item: $passEditor) { mode in PassEditorView(mode: mode) }
            .sheet(isPresented: $showingPaymentEditor) { PaymentEditorView() }
            .confirmationDialog("결제 완료로 처리할까요?", isPresented: Binding(
                get: { payTarget != nil }, set: { if !$0 { payTarget = nil } }
            ), titleVisibility: .visible, presenting: payTarget) { payment in
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Button(method.displayName) { markPaid(payment, method: method) }
                }
            } message: { _ in
                Text("테스트 단계라 실제 결제는 일어나지 않아요. 받은 방법만 표시해요.")
            }
            .confirmationDialog("이용권을 삭제할까요?", isPresented: Binding(
                get: { deletePassTarget != nil }, set: { if !$0 { deletePassTarget = nil } }
            ), titleVisibility: .visible, presenting: deletePassTarget) { pass in
                Button("삭제", role: .destructive) { deletePass(pass) }
            }
        }
    }

    private func petIDs(for user: User) -> Set<String> { Set(notebook.opsPets(for: user).map(\.id)) }

    private func content(_ user: User) -> some View {
        let tabs = Permissions.canViewPayments(user) ? Tab.allCases : [.passes]
        let ids = petIDs(for: user)
        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                if tabs.count > 1 {
                    Picker("보기", selection: $tab) {
                        ForEach(tabs, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Text("테스트 단계라 실제 결제 시스템과 연결되어 있지 않아요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                switch tabs.contains(tab) ? tab : .passes {
                case .passes: passes(user, ids: ids)
                case .payments: payments(user, ids: ids)
                case .unpaid: unpaid(user, ids: ids)
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    // MARK: 이용권

    @ViewBuilder
    private func passes(_ user: User, ids: Set<String>) -> some View {
        let list = billing.passes.filter { ids.contains($0.petID) }.sorted { $0.expiryDate < $1.expiryDate }
        if list.isEmpty { OpsEmptyCard(text: "등록된 이용권이 없어요") }
        ForEach(list) { pass in passCard(pass, user: user) }
    }

    private func passCard(_ pass: Pass, user: User) -> some View {
        let days = pass.daysUntilExpiry()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(notebook.petName(pass.petID)) · \(pass.title)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                if pass.isExpired() {
                    OpsPill(text: String(localized: "만료"), color: AppTheme.statusRejected)
                } else if pass.remainingCount == 0 {
                    OpsPill(text: String(localized: "소진"), color: AppTheme.statusRejected)
                } else if days <= 7 || pass.remainingCount <= 2 {
                    OpsPill(text: String(localized: "곧 끝나요"), color: AppTheme.statusPending)
                } else {
                    OpsPill(text: String(localized: "이용 중"), color: AppTheme.statusApproved)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text("남은 횟수 \(pass.remainingCount)회")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.text)
                Text("/ \(pass.totalCount)회")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            ProgressView(value: Double(pass.remainingCount), total: Double(max(pass.totalCount, 1)))
                .tint(AppTheme.buttonShadow)
            Text("만료일 \(pass.expiryDate.formatted(date: .abbreviated, time: .omitted))" +
                 (pass.isExpired() ? "" : " · " + (days == 0 ? String(localized: "오늘까지") : String(localized: "\(days)일 남음"))))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(pass.isExpired() || days <= 7 ? AppTheme.statusPending : AppTheme.subText)
            if Permissions.canManageBilling(user) {
                HStack(spacing: 8) {
                    Button("수정") { passEditor = .edit(pass) }.buttonStyle(AnyButtonStyle.soft)
                    Button("삭제") { deletePassTarget = pass }.buttonStyle(AnyButtonStyle.soft)
                }
            }
        }
        .opsCard()
    }

    // MARK: 결제 내역

    @ViewBuilder
    private func payments(_ user: User, ids: Set<String>) -> some View {
        let list = billing.payments(petIDs: ids)
        if list.isEmpty { OpsEmptyCard(text: "결제 내역이 없어요") }
        ForEach(list) { paymentCard($0, user: user) }
    }

    private func paymentCard(_ payment: Payment, user: User) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(notebook.petName(payment.petID)) · \(payment.title)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                OpsPill(text: billing.isOverdue(payment) ? String(localized: "기한 지남") : payment.status.displayName,
                        color: payment.status == .paid ? AppTheme.statusApproved
                            : (billing.isOverdue(payment) ? AppTheme.statusRejected : AppTheme.statusPending))
            }
            Text(payment.amount.formatted(.number) + String(localized: "원"))
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.text)
            if user.role == .owner {
                Text("보호자 \(notebook.authorName(payment.parentID))")
                    .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
            }
            if let paidDate = payment.paidDate {
                Text("\(paidDate.formatted(date: .abbreviated, time: .omitted)) · \(payment.method?.displayName ?? "")")
                    .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
            } else {
                Text("결제 기한 \(payment.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
            }
            if Permissions.canManageBilling(user) {
                HStack(spacing: 8) {
                    if payment.status == .unpaid {
                        Button("결제 완료 처리") { payTarget = payment }.buttonStyle(AnyButtonStyle.gradient)
                        Button("납부 안내") { remind(payment) }.buttonStyle(AnyButtonStyle.soft)
                    }
                    Button("삭제") { billing.deletePayment(id: payment.id) }.buttonStyle(AnyButtonStyle.soft)
                }
            }
        }
        .opsCard()
    }

    // MARK: 미결제

    @ViewBuilder
    private func unpaid(_ user: User, ids: Set<String>) -> some View {
        let list = billing.unpaid(petIDs: ids)
        let total = list.reduce(0) { $0 + $1.amount }
        VStack(alignment: .leading, spacing: 4) {
            Text("미결제 합계")
                .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
            Text(total.formatted(.number) + String(localized: "원"))
                .font(AppTheme.Typography.title)
                .foregroundStyle(list.isEmpty ? AppTheme.statusApproved : AppTheme.statusRejected)
            Text("\(list.count)건 · 기한 지난 \(list.filter(billing.isOverdue).count)건")
                .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
        }
        .opsCard()
        if list.isEmpty { OpsEmptyCard(text: "미결제 내역이 없어요 🎉") }
        ForEach(list) { paymentCard($0, user: user) }
    }

    // MARK: 동작

    private func markPaid(_ payment: Payment, method: PaymentMethod) {
        guard let user = session.currentUser, Permissions.canManageBilling(user) else { return }
        billing.markPaid(id: payment.id, method: method)
        notifications.send(to: payment.parentID, title: String(localized: "결제가 확인됐어요"),
                           content: String(localized: "\(payment.title) \(payment.amount.formatted(.number))원 결제가 확인됐어요."))
        payTarget = nil
    }

    private func remind(_ payment: Payment) {
        guard let user = session.currentUser, Permissions.canManageBilling(user) else { return }
        notifications.send(to: payment.parentID, title: String(localized: "미결제 안내"),
                           content: String(localized: "\(payment.title) \(payment.amount.formatted(.number))원이 아직 결제되지 않았어요."))
    }

    private func deletePass(_ pass: Pass) {
        guard let user = session.currentUser, Permissions.canManageBilling(user) else { return }
        billing.deletePass(id: pass.id)
        deletePassTarget = nil
    }
}

enum PassEditorMode: Identifiable {
    case create
    case edit(Pass)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let pass): "edit-\(pass.id)"
        }
    }
}

/// 이용권 등록·수정 (원장)
struct PassEditorView: View {
    let mode: PassEditorMode

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(BillingStore.self) private var billing
    @State private var petID: String?
    @State private var title: String
    @State private var totalCount: Int
    @State private var start: Date
    @State private var expiry: Date
    @State private var priceText = ""
    @State private var createsPayment = true
    @State private var errorMessage: String?

    init(mode: PassEditorMode) {
        self.mode = mode
        switch mode {
        case .create:
            _petID = State(initialValue: nil)
            _title = State(initialValue: "10회권")
            _totalCount = State(initialValue: 10)
            _start = State(initialValue: .now)
            _expiry = State(initialValue: Calendar.current.date(byAdding: .day, value: 60, to: .now) ?? .now)
        case .edit(let pass):
            _petID = State(initialValue: pass.petID)
            _title = State(initialValue: pass.title)
            _totalCount = State(initialValue: pass.totalCount)
            _start = State(initialValue: pass.startDate)
            _expiry = State(initialValue: pass.expiryDate)
        }
    }

    private var editing: Pass? {
        if case .edit(let pass) = mode { return pass }
        return nil
    }

    private var pets: [Pet] { notebook.pets.filter(\.isApproved) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if editing == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            OpsSectionTitle(text: "반려견")
                            OpsPetChips(pets: pets, selectedID: $petID)
                        }
                        .opsCard()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "이용권 이름")
                        OpsField(placeholder: "예: 10회권", text: $title)
                        Stepper("총 \(totalCount)회", value: $totalCount, in: max(editing?.usedCount ?? 1, 1)...200)
                            .foregroundStyle(AppTheme.text)
                        if let editing {
                            Text("이미 \(editing.usedCount)회 사용해서 그보다 적게 줄일 수 없어요.")
                                .font(AppTheme.Typography.captionRegular).foregroundStyle(AppTheme.subText)
                        }
                    }
                    .opsCard()
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "이용 기간")
                        DatePicker("시작일", selection: $start, displayedComponents: .date).foregroundStyle(AppTheme.text)
                        DatePicker("만료일", selection: $expiry, in: start..., displayedComponents: .date).foregroundStyle(AppTheme.text)
                    }
                    .opsCard()
                    if editing == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            OpsSectionTitle(text: "결제 금액 (테스트용)")
                            OpsField(placeholder: "금액 (원)", text: $priceText, keyboard: .numberPad)
                            Toggle("미결제 내역도 함께 만들기", isOn: $createsPayment).tint(AppTheme.buttonShadow)
                                .foregroundStyle(AppTheme.text)
                        }
                        .opsCard()
                    }
                    if let errorMessage {
                        Text(errorMessage).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.statusRejected)
                    }
                    Button("저장", action: save).buttonStyle(GradientButtonStyle())
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(editing == nil ? "이용권 등록" : "이용권 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }

    private func save() {
        guard let user = session.currentUser, Permissions.canManageBilling(user) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard let petID = petID ?? pets.first?.id, !cleanTitle.isEmpty else {
            errorMessage = String(localized: "반려견과 이용권 이름을 확인해 주세요.")
            return
        }
        guard expiry >= start else {
            errorMessage = String(localized: "만료일은 시작일 이후여야 해요.")
            return
        }
        if var pass = editing {
            pass.title = cleanTitle
            pass.totalCount = max(totalCount, pass.usedCount)
            pass.startDate = start
            pass.expiryDate = expiry
            billing.save(pass: pass)
        } else {
            let pass = Pass(id: UUID().uuidString, petID: petID, title: cleanTitle, totalCount: totalCount,
                            startDate: start, expiryDate: expiry, createdByID: user.id)
            billing.save(pass: pass)
            if createsPayment, let price = Int(priceText), price > 0,
               let ownerID = notebook.pets.first(where: { $0.id == petID })?.ownerID {
                billing.save(payment: Payment(id: UUID().uuidString, petID: petID, parentID: ownerID, title: cleanTitle,
                                              amount: price, status: .unpaid,
                                              dueDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
                                              passID: pass.id, createdByID: user.id))
            }
        }
        dismiss()
    }
}

/// 결제 내역 직접 추가 (원장)
struct PaymentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(BillingStore.self) private var billing
    @State private var petID: String?
    @State private var title = ""
    @State private var amountText = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var errorMessage: String?

    private var pets: [Pet] { notebook.pets.filter(\.isApproved) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "반려견")
                        OpsPetChips(pets: pets, selectedID: $petID)
                    }
                    .opsCard()
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "내용")
                        OpsField(placeholder: "예: 간식비, 특별 수업", text: $title)
                        OpsField(placeholder: "금액 (원)", text: $amountText, keyboard: .numberPad)
                        DatePicker("결제 기한", selection: $dueDate, displayedComponents: .date).foregroundStyle(AppTheme.text)
                    }
                    .opsCard()
                    if let errorMessage {
                        Text(errorMessage).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.statusRejected)
                    }
                    Button("미결제로 추가", action: save).buttonStyle(GradientButtonStyle())
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("결제 내역 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }

    private func save() {
        guard let user = session.currentUser, Permissions.canManageBilling(user) else { return }
        guard let petID = petID ?? pets.first?.id,
              let ownerID = notebook.pets.first(where: { $0.id == petID })?.ownerID,
              !title.trimmingCharacters(in: .whitespaces).isEmpty,
              let amount = Int(amountText), amount > 0 else {
            errorMessage = String(localized: "반려견, 내용, 금액(1원 이상)을 확인해 주세요.")
            return
        }
        billing.save(payment: Payment(id: UUID().uuidString, petID: petID, parentID: ownerID,
                                      title: title.trimmingCharacters(in: .whitespaces), amount: amount,
                                      status: .unpaid, dueDate: dueDate, createdByID: user.id))
        dismiss()
    }
}

// MARK: - 월별 출석 현황

struct AttendanceMonthSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(AttendanceStore.self) private var attendance
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedPetID: String?

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canViewAttendance(user) {
                    content(user)
                } else {
                    Text("볼 수 없는 화면이에요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("월별 출석 현황")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { CloseButton() } }
        }
    }

    private func content(_ user: User) -> some View {
        let pets = notebook.opsPets(for: user).filter(\.isApproved)
        let ids = Set(pets.map(\.id))
        let counts = attendance.monthlyCounts(inMonth: month, petIDs: ids)
        let shownIDs: Set<String> = selectedPetID.map { [$0] } ?? ids
        let entries = attendance.entries(inMonth: month, petIDs: shownIDs).sorted { $0.checkIn > $1.checkIn }
        let attendedDays = Set(entries.map { calendar.startOfDay(for: $0.day) })
        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("이전 달")
                    Spacer()
                    Text(month.formatted(.dateTime.year().month(.wide)))
                        .font(AppTheme.Typography.title).foregroundStyle(AppTheme.text)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .accessibilityLabel("다음 달")
                        .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
                }
                .foregroundStyle(AppTheme.softButtonText)

                // 반려견별 출석일 수
                VStack(alignment: .leading, spacing: 8) {
                    OpsSectionTitle(text: "반려견별 출석일")
                    if pets.isEmpty { Text("볼 수 있는 반려견이 없어요").font(AppTheme.Typography.body).foregroundStyle(AppTheme.subText) }
                    ForEach(pets) { pet in
                        HStack {
                            Text(pet.name).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.text)
                            Spacer()
                            Text("\(counts[pet.id] ?? 0)일").font(AppTheme.Typography.headline).foregroundStyle(AppTheme.softButtonText)
                        }
                    }
                }
                .opsCard()

                // 달력 (출석한 날 표시)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        OpsSectionTitle(text: "출석 달력")
                        Spacer()
                        Text("\(attendedDays.count)일 출석").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
                    }
                    if pets.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                chip(String(localized: "전체"), isOn: selectedPetID == nil) { selectedPetID = nil }
                                ForEach(pets) { pet in chip(pet.name, isOn: selectedPetID == pet.id) { selectedPetID = pet.id } }
                            }
                        }
                    }
                    calendarGrid(attendedDays: attendedDays)
                }
                .opsCard()

                OpsSectionTitle(text: "출석 기록")
                if entries.isEmpty { OpsEmptyCard(text: "이 달에는 출석 기록이 없어요") }
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.day.formatted(.dateTime.month().day().weekday(.abbreviated)))
                                .font(AppTheme.Typography.headline).foregroundStyle(AppTheme.text)
                            Text(notebook.petName(entry.petID)).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
                        }
                        Spacer()
                        Text("\(entry.checkIn.formatted(date: .omitted, time: .shortened)) ~ \(entry.checkOut?.formatted(date: .omitted, time: .shortened) ?? String(localized: "유치원에 있어요"))")
                            .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
                    }
                    .opsCard(padding: 12)
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func moveMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        month = next
    }

    private func calendarGrid(attendedDays: Set<Date>) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let names = Array(symbols[first...] + symbols[..<first])
        var cells: [Date?] = []
        if let interval = calendar.dateInterval(of: .month, for: month),
           let range = calendar.range(of: .day, in: .month, for: month) {
            let weekday = calendar.component(.weekday, from: interval.start)
            cells = Array(repeating: nil, count: (weekday - calendar.firstWeekday + 7) % 7)
            for day in range { cells.append(calendar.date(byAdding: .day, value: day - 1, to: interval.start)) }
        }
        return VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(names, id: \.self) { Text($0).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText) }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let attended = attendedDays.contains(calendar.startOfDay(for: day))
                        Text("\(calendar.component(.day, from: day))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(attended ? AppTheme.buttonText : AppTheme.text)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background { if attended { Circle().fill(AppTheme.button) } }
                            .accessibilityLabel(day.formatted(.dateTime.month().day()) + (attended ? String(localized: ", 출석") : ""))
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
    }
}
