import SwiftUI

/// 훈련 상세에 붙는 "맞춤 계획" 카드: 이 반려견만의 목표, 담당 선생님, 가정교육 방법.
/// 원장·선생님은 고칠 수 있고, 보호자는 내 반려견 것만 볼 수 있어요.
struct TrainingPlanCard: View {
    let training: Training
    let petID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(PetDetailStore.self) private var details
    @Environment(TrainingProgressStore.self) private var progress
    @State private var editingPlan = false
    @State private var editingCustom = false
    @State private var confirmingDelete = false

    private var plan: TrainingPlan? { details.plan(petID: petID, trainingID: training.id) }
    private var canManage: Bool { session.currentUser.map(Permissions.canManageTrainingPlan) ?? false }
    private var currentPercent: Int { progress.percent(petID: petID, trainingID: training.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("맞춤 훈련 계획")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                if canManage {
                    Button("수정") { editingPlan = true }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.softButtonText)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            if let plan {
                // 목표 진행률
                HStack {
                    Text("목표 \(plan.goalPercent)%")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.softButtonText)
                    Text("(지금 \(currentPercent)%)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                    Spacer()
                    if currentPercent >= plan.goalPercent {
                        OpsPill(text: String(localized: "목표 달성"), color: AppTheme.statusApproved)
                    }
                }
                ProgressView(value: Double(min(currentPercent, plan.goalPercent)), total: Double(max(plan.goalPercent, 1)))
                    .tint(AppTheme.buttonShadow)
                if !plan.goalNote.isEmpty {
                    OpsInfoRow(title: String(localized: "목표"), value: plan.goalNote)
                }
                if let date = plan.targetDate {
                    OpsInfoRow(title: String(localized: "목표일"), value: date.formatted(date: .abbreviated, time: .omitted))
                }
                OpsInfoRow(title: String(localized: "담당 선생님"),
                           value: plan.teacherID.map { notebook.authorName($0) } ?? "",
                           emptyText: String(localized: "정해지지 않았어요"))
                if !plan.homeGuide.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("집에서 이렇게 해 주세요", systemImage: "house.fill")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(AppTheme.softButtonText)
                        Text(plan.homeGuide)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.softButton, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                Text(canManage ? "아직 목표와 담당 선생님이 없어요. 수정 버튼으로 정해 주세요." : "아직 맞춤 계획이 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
                if let last = progress.history(petID: petID, trainingID: training.id).first {
                    Text("최근 기록한 선생님: \(notebook.authorName(last.recordedByID))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
            }
            if canManage && details.isCustom(trainingID: training.id) {
                HStack(spacing: 10) {
                    Button("훈련 항목 수정") { editingCustom = true }.buttonStyle(AnyButtonStyle.soft)
                    Button("항목 삭제") { confirmingDelete = true }.buttonStyle(AnyButtonStyle.soft)
                }
                .padding(.top, 4)
            }
        }
        .opsCard()
        .sheet(isPresented: $editingPlan) { TrainingPlanEditorSheet(training: training, petID: petID, existing: plan) }
        .sheet(isPresented: $editingCustom) {
            if let custom = details.customTraining(id: training.id) {
                CustomTrainingEditorView(petID: petID, existing: custom) { dismiss() }
            }
        }
        .confirmationDialog("이 훈련 항목을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { deleteCustom() }
        } message: {
            Text("이 반려견의 \(training.title) 진행 기록도 함께 지워져요.")
        }
    }

    private func deleteCustom() {
        guard canManage, details.isCustom(trainingID: training.id) else { return }
        for item in progress.items where item.trainingID == training.id { progress.delete(id: item.id) }
        details.deleteCustomTraining(id: training.id)
        dismiss()
    }
}

/// 목표·담당 선생님·가정교육 안내 수정 창
struct TrainingPlanEditorSheet: View {
    let training: Training
    let petID: String
    let existing: TrainingPlan?

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(PetDetailStore.self) private var details
    @Environment(NotificationStore.self) private var notifications
    @State private var goalPercent: Int
    @State private var goalNote: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var teacherID: String?
    @State private var homeGuide: String

    init(training: Training, petID: String, existing: TrainingPlan?) {
        self.training = training
        self.petID = petID
        self.existing = existing
        _goalPercent = State(initialValue: existing?.goalPercent ?? 100)
        _goalNote = State(initialValue: existing?.goalNote ?? "")
        _hasTargetDate = State(initialValue: existing?.targetDate != nil)
        _targetDate = State(initialValue: existing?.targetDate ?? Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now)
        _teacherID = State(initialValue: existing?.teacherID)
        _homeGuide = State(initialValue: existing?.homeGuide ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "목표 진행률")
                        Picker("목표", selection: $goalPercent) {
                            ForEach(Array(stride(from: 10, through: 100, by: 10)), id: \.self) { Text("\($0)%").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 110)
                        .clipped()
                        OpsField(placeholder: "목표 설명 (예: 산책 중 줄 당기지 않기)", text: $goalNote, multiline: true)
                        Toggle("목표 날짜 정하기", isOn: $hasTargetDate).tint(AppTheme.buttonShadow).foregroundStyle(AppTheme.text)
                        if hasTargetDate {
                            DatePicker("목표일", selection: $targetDate, in: Date.now..., displayedComponents: .date)
                                .foregroundStyle(AppTheme.text)
                        }
                    }
                    .opsCard()
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "담당 선생님")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(notebook.staffUsers) { staff in
                                    let isOn = teacherID == staff.id
                                    Button { teacherID = staff.id } label: {
                                        Text(staff.name)
                                            .font(AppTheme.Typography.headline)
                                            .padding(.horizontal, 16).frame(minHeight: 44)
                                            .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                                            .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(isOn ? .isSelected : [])
                                }
                            }
                        }
                    }
                    .opsCard()
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "보호자에게 알려 줄 가정교육 방법")
                        OpsField(placeholder: "집에서 연습하는 방법을 적어 주세요", text: $homeGuide, multiline: true)
                    }
                    .opsCard()
                    Button("저장", action: save).buttonStyle(GradientButtonStyle())
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("\(training.title) 계획")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }

    private func save() {
        guard let user = session.currentUser, Permissions.canManageTrainingPlan(user) else { return }
        let guide = homeGuide.trimmingCharacters(in: .whitespacesAndNewlines)
        details.save(plan: TrainingPlan(petID: petID, trainingID: training.id, goalPercent: goalPercent,
                                        goalNote: goalNote.trimmingCharacters(in: .whitespacesAndNewlines),
                                        targetDate: hasTargetDate ? targetDate : nil,
                                        teacherID: teacherID ?? user.id, homeGuide: guide))
        // 가정교육 안내가 새로 생기거나 바뀌면 보호자에게 알려요.
        if !guide.isEmpty, guide != existing?.homeGuide,
           let pet = notebook.pets.first(where: { $0.id == petID }) {
            notifications.send(to: pet.ownerID, title: String(localized: "가정교육 안내가 도착했어요"),
                               content: String(localized: "\(pet.name)의 \(training.title) 훈련을 집에서 연습하는 방법이 올라왔어요."))
        }
        dismiss()
    }
}

/// 반려견별 훈련 항목 추가·수정 창
struct CustomTrainingEditorView: View {
    let petID: String
    let existing: CustomTraining?
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(PetDetailStore.self) private var details
    @State private var title: String
    @State private var summary: String
    @State private var difficulty: TrainingDifficulty
    @State private var stepsText: String
    @State private var tip: String
    @State private var symbol: String

    private static let symbols = ["star.fill", "pawprint.fill", "heart.fill", "bolt.fill", "leaf.fill", "bell.fill"]

    init(petID: String, existing: CustomTraining?, onSaved: @escaping () -> Void = {}) {
        self.petID = petID
        self.existing = existing
        self.onSaved = onSaved
        _title = State(initialValue: existing?.title ?? "")
        _summary = State(initialValue: existing?.summary ?? "")
        _difficulty = State(initialValue: existing?.difficulty ?? .beginner)
        _stepsText = State(initialValue: existing?.steps.joined(separator: "\n") ?? "")
        _tip = State(initialValue: existing?.tip ?? "")
        _symbol = State(initialValue: existing?.symbol ?? "star.fill")
    }

    private var petName: String { notebook.petName(petID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Text("\(petName)에게만 보이는 훈련이에요.")
                        .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "훈련 이름")
                        OpsField(placeholder: "예: 하우스", text: $title)
                        OpsField(placeholder: "한 줄 설명", text: $summary)
                    }
                    .opsCard()
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "난이도")
                        ChoiceChips(options: TrainingDifficulty.allCases, selection: $difficulty) { $0.displayName }
                        OpsSectionTitle(text: "그림")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Self.symbols, id: \.self) { name in
                                    let isOn = symbol == name
                                    Button { symbol = name } label: {
                                        Image(systemName: name)
                                            .frame(width: 48, height: 48)
                                            .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                                            .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(name)
                                    .accessibilityAddTraits(isOn ? .isSelected : [])
                                }
                            }
                        }
                    }
                    .opsCard()
                    VStack(alignment: .leading, spacing: 10) {
                        OpsSectionTitle(text: "훈련 순서 (한 줄에 한 단계)")
                        OpsField(placeholder: "1단계\n2단계\n3단계", text: $stepsText, multiline: true)
                        OpsSectionTitle(text: "선생님 팁")
                        OpsField(placeholder: "팁 (선택)", text: $tip, multiline: true)
                    }
                    .opsCard()
                    Button("저장", action: save)
                        .buttonStyle(GradientButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "훈련 항목 추가" : "훈련 항목 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }

    private func save() {
        guard let user = session.currentUser, Permissions.canManageTrainingPlan(user) else { return }
        let steps = stepsText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        details.save(custom: CustomTraining(
            id: existing?.id ?? "custom-" + UUID().uuidString, petID: petID,
            title: title.trimmingCharacters(in: .whitespaces),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            difficulty: difficulty, steps: steps.isEmpty ? [String(localized: "선생님과 함께 연습해요")] : steps,
            tip: tip.trimmingCharacters(in: .whitespacesAndNewlines), symbol: symbol))
        dismiss()
        if existing != nil { onSaved() }
    }
}
