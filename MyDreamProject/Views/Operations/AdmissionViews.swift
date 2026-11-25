import SwiftUI
import PhotosUI

/// 원장·선생님용: 입학 절차 중인 반려견 목록. 누르면 확인·평가·최종 승인 화면으로 가요.
struct AdmissionListSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(AdmissionStore.self) private var admission

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canVerifyAdmission(user) {
                    list
                } else {
                    Text("원장님과 선생님만 볼 수 있어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background.ignoresSafeArea())
                }
            }
            .navigationTitle("입학 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { CloseButton() } }
        }
    }

    private var list: some View {
        // 반려된 신청은 입학 절차 대상이 아니에요.
        let pets = notebook.pets.filter { $0.status != .rejected }
        let inProgress = pets.filter { admission.record(petID: $0.id).decision == .inProgress }
        let finished = pets.filter { admission.record(petID: $0.id).decision != .inProgress }
        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                Text("예방접종·중성화·동물등록이 모두 확인되고, 무료 하루 체험과 평가를 마쳐야 원장님이 최종 입학 승인을 할 수 있어요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                OpsSectionTitle(text: "진행 중")
                if inProgress.isEmpty { OpsEmptyCard(text: "진행 중인 입학 절차가 없어요") }
                ForEach(inProgress) { pet in row(pet) }
                if !finished.isEmpty {
                    OpsSectionTitle(text: "처리 완료")
                    ForEach(finished) { pet in row(pet) }
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func row(_ pet: Pet) -> some View {
        let record = admission.record(petID: pet.id)
        return NavigationLink {
            ScrollView {
                AdmissionDetailContent(petID: pet.id).padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("\(pet.name) 입학")
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(pet.name) · \(pet.breed)")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    AdmissionDecisionPill(decision: record.decision)
                }
                Text("보호자 \(notebook.authorName(pet.ownerID))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                if record.decision == .inProgress {
                    Text(record.missingConditions.isEmpty
                         ? String(localized: "필수 조건 확인 완료")
                         : String(localized: "확인 필요: \(record.missingConditions.map(\.title).joined(separator: ", "))"))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(record.missingConditions.isEmpty ? AppTheme.statusApproved : AppTheme.statusPending)
                }
            }
            .opsCard()
        }
        .buttonStyle(.plain)
    }
}

/// 보호자용: 내 반려견의 입학 절차 화면 (증명서 첨부, 동물등록번호, 체험 예약)
struct AdmissionDetailSheet: View {
    let petID: String

    var body: some View {
        OpsSheet(title: "입학 절차") {
            AdmissionDetailContent(petID: petID)
        }
    }
}

struct AdmissionDecisionPill: View {
    let decision: AdmissionDecision

    var body: some View {
        OpsPill(text: decision.displayName, color: {
            switch decision {
            case .inProgress: AppTheme.statusPending
            case .admitted: AppTheme.statusApproved
            case .declined: AppTheme.statusRejected
            }
        }())
    }
}

struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("닫기") { dismiss() } }
}

/// 입학 절차 한 마리 분량의 내용 (보호자·직원이 함께 써요. 권한에 따라 버튼이 달라져요)
struct AdmissionDetailContent: View {
    let petID: String

    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(AdmissionStore.self) private var admission
    @Environment(ReservationStore.self) private var reservations
    @Environment(NotificationStore.self) private var notifications
    @State private var pickerItem: PhotosPickerItem?
    @State private var numberText = ""
    @State private var didLoadNumber = false
    @State private var trialDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
    @State private var trialNote = ""
    @State private var showingEvaluation = false
    @State private var confirmingApprove = false
    @State private var declining = false
    @State private var declineReason = ""
    @State private var message: String?

    private var pet: Pet? { notebook.pets.first { $0.id == petID } }
    private var trial: Reservation? { reservations.latest(kind: .trial, petID: petID) }
    private var trialCompleted: Bool { trial?.status == .completed }

    var body: some View {
        if let user = session.currentUser, let pet {
            let record = admission.record(petID: petID)
            let canDocs = Permissions.canSubmitAdmissionDocs(user, pet: pet)
            let canVerify = Permissions.canVerifyAdmission(user)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                HStack {
                    Text(pet.name).font(AppTheme.Typography.title).foregroundStyle(AppTheme.text)
                    Spacer()
                    AdmissionDecisionPill(decision: record.decision)
                }
                if record.decision == .declined {
                    Text("입학 불가 사유: \(record.declineReason)")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.statusRejected)
                        .opsCard()
                }
                if let message {
                    Text(message).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.statusRejected)
                }
                conditionsCard(pet, record: record, canDocs: canDocs, canVerify: canVerify, user: user)
                trialCard(pet, canDocs: canDocs, canVerify: canVerify, user: user)
                if canVerify { evaluationCard(record, user: user) }
                else if record.evaluation != nil { parentEvaluationNotice }
                decisionCard(pet, record: record, user: user)
            }
            .onAppear {
                if !didLoadNumber { numberText = record.animalRegistrationNumber; didLoadNumber = true }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), canDocs {
                        admission.attachCertificate(petID: petID, photo: .data(PhotoRenderer.compressed(data)))
                    }
                    pickerItem = nil
                }
            }
            .sheet(isPresented: $showingEvaluation) {
                TrialEvaluationSheet(petID: petID, existing: record.evaluation)
            }
            .alert("입학 불가 처리", isPresented: $declining) {
                TextField("사유", text: $declineReason)
                Button("처리", role: .destructive) { decline(pet, user: user) }
                Button("취소", role: .cancel) {}
            } message: {
                Text("보호자에게 전달할 사유를 적어 주세요.")
            }
            .confirmationDialog("최종 입학을 승인할까요?", isPresented: $confirmingApprove, titleVisibility: .visible) {
                Button("입학 승인") { approve(pet, user: user) }
            } message: {
                Text("\(pet.name)의 보호자에게 입학 승인 알림이 가요.")
            }
        } else {
            OpsEmptyCard(text: "반려견 정보를 찾을 수 없어요")
        }
    }

    // MARK: 필수 입학 조건

    private func conditionsCard(_ pet: Pet, record: AdmissionRecord, canDocs: Bool, canVerify: Bool, user: User) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            OpsSectionTitle(text: "필수 입학 조건")
            Text("세 가지가 모두 확인돼야 입학할 수 있어요.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)

            // 1. 예방접종 증명서
            VStack(alignment: .leading, spacing: 8) {
                conditionHeader(.vaccination, met: record.isMet(.vaccination))
                Text("신청 정보: \(pet.profile?.vaccination.displayName ?? String(localized: "정보 없음"))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                if let certificate = record.vaccinationCertificate {
                    PhotoImageView(source: certificate)
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    HStack(spacing: 8) {
                        if canVerify {
                            Button(record.vaccinationVerified ? String(localized: "확인 취소") : String(localized: "증명서 확인 완료")) {
                                admission.verifyVaccination(petID: petID, verified: !record.vaccinationVerified, staffID: user.id)
                            }
                            .buttonStyle(record.vaccinationVerified ? AnyButtonStyle.soft : AnyButtonStyle.gradient)
                        } else {
                            Text(record.vaccinationVerified ? String(localized: "직원이 확인했어요") : String(localized: "직원이 확인하는 중이에요"))
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.subText)
                        }
                        if canDocs {
                            Button("삭제") { admission.removeCertificate(petID: petID) }
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.statusRejected)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                } else {
                    Text("아직 첨부된 증명서가 없어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                }
                if canDocs {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(record.vaccinationCertificate == nil ? "증명서 사진 첨부" : "다른 사진으로 바꾸기", systemImage: "paperclip")
                            .font(AppTheme.Typography.buttonLabel)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(AppTheme.softButtonText)
                            .background(AppTheme.softButton, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            Divider()

            // 2. 중성화
            VStack(alignment: .leading, spacing: 8) {
                conditionHeader(.neutered, met: record.isMet(.neutered))
                Text("신청 정보: \((pet.profile?.isNeutered ?? false) ? String(localized: "중성화함") : String(localized: "중성화 안 함"))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                if canVerify {
                    Button(record.neuterConfirmed ? String(localized: "확인 취소") : String(localized: "중성화 완료 확인")) {
                        admission.confirmNeutered(petID: petID, confirmed: !record.neuterConfirmed, staffID: user.id)
                    }
                    .buttonStyle(record.neuterConfirmed ? AnyButtonStyle.soft : AnyButtonStyle.gradient)
                } else {
                    Text(record.neuterConfirmed ? String(localized: "직원이 확인했어요") : String(localized: "직원이 확인하는 중이에요"))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
            }
            Divider()

            // 3. 동물등록번호
            VStack(alignment: .leading, spacing: 8) {
                conditionHeader(.animalRegistration, met: record.isMet(.animalRegistration))
                if canDocs {
                    OpsField(placeholder: "동물등록번호 15자리 숫자", text: $numberText, keyboard: .numberPad)
                    let digits = AdmissionRecord.digits(numberText)
                    if !numberText.isEmpty && digits.count != 15 {
                        Text("숫자 15자리를 입력해 주세요. (지금 \(digits.count)자리)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.statusRejected)
                    }
                    Button("번호 저장") {
                        guard digits.count == 15 else { return }
                        admission.setRegistrationNumber(petID: petID, number: digits)
                    }
                    .buttonStyle(AnyButtonStyle.soft)
                    .disabled(digits.count != 15)
                } else {
                    OpsInfoRow(title: String(localized: "번호"), value: record.animalRegistrationNumber)
                }
                if canVerify {
                    Button(record.registrationVerified ? String(localized: "확인 취소") : String(localized: "등록번호 확인 완료")) {
                        admission.verifyRegistration(petID: petID, verified: !record.registrationVerified, staffID: user.id)
                    }
                    .buttonStyle(record.registrationVerified ? AnyButtonStyle.soft : AnyButtonStyle.gradient)
                    .disabled(!record.hasValidRegistrationNumber)
                } else if record.hasValidRegistrationNumber {
                    Text(record.registrationVerified ? String(localized: "직원이 확인했어요") : String(localized: "직원이 확인하는 중이에요"))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
            }
        }
        .opsCard()
    }

    private func conditionHeader(_ condition: AdmissionCondition, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? AppTheme.statusApproved : AppTheme.subText)
            Text(condition.title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            Spacer()
            OpsPill(text: met ? String(localized: "확인 완료") : String(localized: "확인 필요"),
                    color: met ? AppTheme.statusApproved : AppTheme.statusPending)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 무료 하루 체험 예약

    private func trialCard(_ pet: Pet, canDocs: Bool, canVerify: Bool, user: User) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OpsSectionTitle(text: "무료 하루 체험")
            if let trial {
                HStack {
                    Label(trial.start.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    ReservationStatusPill(status: trial.status)
                }
                if !trial.note.isEmpty {
                    Text(trial.note).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
                }
                if canVerify {
                    HStack(spacing: 10) {
                        if trial.status == .requested {
                            Button("체험 확정") { confirmTrial(trial, pet: pet, user: user) }
                                .buttonStyle(AnyButtonStyle.gradient)
                        }
                        if trial.status == .confirmed {
                            Button("체험 완료 처리") { completeTrial(trial, pet: pet) }
                                .buttonStyle(AnyButtonStyle.gradient)
                        }
                        if trial.isOpen {
                            Button("체험 취소") { cancelTrial(trial, pet: pet) }
                                .buttonStyle(AnyButtonStyle.soft)
                        }
                    }
                } else if trial.isOpen && Permissions.canModify(trial, by: user) {
                    Button("체험 취소") { cancelTrial(trial, pet: pet) }
                        .buttonStyle(AnyButtonStyle.soft)
                }
            } else if canDocs {
                Text("입학 전에 하루 동안 무료로 체험해 볼 수 있어요. 원하는 날짜를 골라 예약해 주세요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                DatePicker("체험 날짜", selection: $trialDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    .foregroundStyle(AppTheme.text)
                OpsField(placeholder: "전달할 말 (선택)", text: $trialNote)
                Button("무료 체험 예약하기") { requestTrial(pet, user: user) }
                    .buttonStyle(AnyButtonStyle.gradient)
            } else {
                Text("아직 체험 예약이 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
            }
        }
        .opsCard()
    }

    // MARK: 체험 후 평가 (직원)

    private func evaluationCard(_ record: AdmissionRecord, user: User) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OpsSectionTitle(text: "체험 후 성향 · 적합성 평가")
            if let evaluation = record.evaluation {
                OpsInfoRow(title: String(localized: "사회성"), value: "\(evaluation.sociability) / 5")
                OpsInfoRow(title: String(localized: "활동량"), value: "\(evaluation.energy) / 5")
                OpsInfoRow(title: String(localized: "불안"), value: "\(evaluation.anxiety) / 5")
                OpsInfoRow(title: String(localized: "공격성"), value: "\(evaluation.aggression) / 5")
                OpsInfoRow(title: String(localized: "적합성"), value: evaluation.suitability.displayName)
                OpsInfoRow(title: String(localized: "의견"), value: evaluation.comment)
                Text("평가자 \(notebook.authorName(evaluation.evaluatorID)) · \(evaluation.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(AppTheme.subText)
            }
            if trialCompleted {
                Button(record.evaluation == nil ? "평가 작성" : "평가 수정") { showingEvaluation = true }
                    .buttonStyle(AnyButtonStyle.soft)
            } else {
                Text("체험을 마치면 평가를 작성할 수 있어요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
        }
        .opsCard()
    }

    private var parentEvaluationNotice: some View {
        Label("체험 후 평가가 끝났어요. 원장님이 최종 결정을 해요.", systemImage: "checkmark.seal.fill")
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.softButtonText)
            .opsCard()
    }

    // MARK: 최종 입학 승인 (원장)

    @ViewBuilder
    private func decisionCard(_ pet: Pet, record: AdmissionRecord, user: User) -> some View {
        if Permissions.canDecideAdmission(user) {
            let blockers = admission.approvalBlockers(petID: petID, trialCompleted: trialCompleted)
            VStack(alignment: .leading, spacing: 10) {
                OpsSectionTitle(text: "최종 입학 승인")
                if record.decision == .admitted {
                    Label("입학이 승인됐어요", systemImage: "checkmark.seal.fill")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.statusApproved)
                } else {
                    ForEach(blockers, id: \.self) { blocker in
                        Label(blocker, systemImage: "exclamationmark.circle")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.statusPending)
                    }
                    HStack(spacing: 10) {
                        Button("입학 불가") { declineReason = ""; declining = true }
                            .buttonStyle(AnyButtonStyle.soft)
                        Button("입학 승인") { confirmingApprove = true }
                            .buttonStyle(AnyButtonStyle.gradient)
                            .disabled(!blockers.isEmpty)
                    }
                }
            }
            .opsCard()
        } else if record.decision == .admitted {
            Label("입학이 승인됐어요 🎉", systemImage: "checkmark.seal.fill")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.statusApproved)
                .opsCard()
        }
    }

    // MARK: 동작 (처리하면 보호자나 직원에게 앱 안 알림이 가요)

    private func requestTrial(_ pet: Pet, user: User) {
        guard Permissions.canSubmitAdmissionDocs(user, pet: pet) else { return }
        guard trial == nil else { return }
        reservations.save(Reservation(id: UUID().uuidString, kind: .trial, petID: petID, parentID: pet.ownerID,
                                      start: trialDate, status: .requested,
                                      note: trialNote.trimmingCharacters(in: .whitespacesAndNewlines)))
        for owner in notebook.staffUsers where owner.role == .owner {
            notifications.send(to: owner.id, title: String(localized: "무료 체험 예약 신청"),
                               content: String(localized: "\(pet.name)의 체험 예약이 들어왔어요."))
        }
    }

    private func confirmTrial(_ trial: Reservation, pet: Pet, user: User) {
        guard Permissions.canVerifyAdmission(user) else { return }
        reservations.confirm(id: trial.id, staffID: user.id)
        notifications.send(to: pet.ownerID, title: String(localized: "무료 체험이 확정됐어요"),
                           content: String(localized: "\(pet.name)의 체험일은 \(trial.start.formatted(date: .abbreviated, time: .shortened))이에요."))
    }

    private func completeTrial(_ trial: Reservation, pet: Pet) {
        guard let user = session.currentUser, Permissions.canVerifyAdmission(user) else { return }
        reservations.complete(id: trial.id)
        notifications.send(to: pet.ownerID, title: String(localized: "무료 체험이 끝났어요"),
                           content: String(localized: "\(pet.name)의 체험 평가를 마치면 입학 결정을 알려 드릴게요."))
    }

    private func cancelTrial(_ trial: Reservation, pet: Pet) {
        guard let user = session.currentUser, Permissions.canModify(trial, by: user) else { return }
        reservations.cancel(id: trial.id, reason: String(localized: "체험 예약 취소"))
        let recipient = user.role == .parent ? nil : pet.ownerID
        if let recipient {
            notifications.send(to: recipient, title: String(localized: "무료 체험이 취소됐어요"),
                               content: String(localized: "\(pet.name)의 체험 예약이 취소됐어요. 다시 예약해 주세요."))
        }
    }

    private func approve(_ pet: Pet, user: User) {
        guard Permissions.canDecideAdmission(user) else { return }
        if admission.approve(petID: petID, trialCompleted: trialCompleted, ownerID: user.id) {
            message = nil
            notifications.send(to: pet.ownerID, title: String(localized: "입학이 승인됐어요 🎉"),
                               content: String(localized: "\(pet.name)의 입학이 승인됐어요. 이제 유치원 이용 예약을 할 수 있어요."))
        } else {
            message = String(localized: "필수 조건이 아직 모두 갖춰지지 않았어요.")
        }
    }

    private func decline(_ pet: Pet, user: User) {
        guard Permissions.canDecideAdmission(user) else { return }
        if admission.decline(petID: petID, reason: declineReason, ownerID: user.id) {
            notifications.send(to: pet.ownerID, title: String(localized: "입학이 어려워요"),
                               content: String(localized: "\(pet.name)의 입학이 어렵다고 결정됐어요. 사유: \(declineReason)"))
        } else {
            message = String(localized: "사유를 적어야 처리할 수 있어요.")
        }
    }
}

/// 체험 후 성향·적합성 평가 작성 창 (원장·선생님)
struct TrialEvaluationSheet: View {
    let petID: String
    let existing: TrialEvaluation?

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(AdmissionStore.self) private var admission
    @State private var sociability: Int
    @State private var energy: Int
    @State private var anxiety: Int
    @State private var aggression: Int
    @State private var suitability: Suitability
    @State private var comment: String

    init(petID: String, existing: TrialEvaluation?) {
        self.petID = petID
        self.existing = existing
        _sociability = State(initialValue: existing?.sociability ?? 3)
        _energy = State(initialValue: existing?.energy ?? 3)
        _anxiety = State(initialValue: existing?.anxiety ?? 3)
        _aggression = State(initialValue: existing?.aggression ?? 1)
        _suitability = State(initialValue: existing?.suitability ?? .suitable)
        _comment = State(initialValue: existing?.comment ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    rating("사회성 (높을수록 좋아요)", $sociability)
                    rating("활동량", $energy)
                    rating("불안 · 분리불안 (높을수록 심해요)", $anxiety)
                    rating("공격성 (높을수록 심해요)", $aggression)
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "적합성")
                        ChoiceChips(options: Suitability.allCases, selection: $suitability) { $0.displayName }
                    }
                    .opsCard()
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "종합 의견")
                        OpsField(placeholder: "체험 중 관찰한 내용을 적어 주세요", text: $comment, multiline: true)
                    }
                    .opsCard()
                    Button("저장", action: save).buttonStyle(GradientButtonStyle())
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("체험 평가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }

    private func rating(_ title: LocalizedStringKey, _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OpsSectionTitle(text: title)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { number in
                    let isOn = value.wrappedValue == number
                    Button { value.wrappedValue = number } label: {
                        Text("\(number)")
                            .font(AppTheme.Typography.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                            .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .opsCard()
    }

    private func save() {
        guard let user = session.currentUser, Permissions.canVerifyAdmission(user) else { return }
        admission.saveEvaluation(petID: petID, evaluation: TrialEvaluation(
            sociability: sociability, energy: energy, anxiety: anxiety, aggression: aggression,
            suitability: suitability, comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            evaluatorID: user.id, date: .now))
        dismiss()
    }
}

/// 버튼 스타일을 조건에 따라 고를 때 쓰는 도우미 (기존 GradientButtonStyle·SoftButtonStyle을 그대로 써요)
struct AnyButtonStyle: ButtonStyle {
    private enum Kind { case gradient, soft }
    private let kind: Kind

    static var gradient: AnyButtonStyle { AnyButtonStyle(kind: .gradient) }
    static var soft: AnyButtonStyle { AnyButtonStyle(kind: .soft) }

    private init(kind: Kind) { self.kind = kind }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        switch kind {
        case .gradient: GradientButtonStyle().makeBody(configuration: configuration)
        case .soft: SoftButtonStyle().makeBody(configuration: configuration)
        }
    }
}

struct ReservationStatusPill: View {
    let status: ReservationStatus

    var body: some View {
        OpsPill(text: status.displayName, color: {
            switch status {
            case .requested: AppTheme.statusPending
            case .confirmed: AppTheme.buttonShadow
            case .cancelled: AppTheme.statusRejected
            case .completed: AppTheme.statusApproved
            }
        }())
    }
}
