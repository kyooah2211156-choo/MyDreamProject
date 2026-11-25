import SwiftUI

/// 건강 기록 입력 화면 (원장·선생님): 응가 횟수, 몸무게(kg, 소수점 둘째 자리), 식사량(g, 5 단위)
struct HealthRecordEditorView: View {
    let petID: String
    let day: Date
    let existing: HealthRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(HealthRecordStore.self) private var health

    @State private var logPoop: Bool
    @State private var poop: Int
    @State private var extra: HealthExtraInput
    @State private var logWeight: Bool
    @State private var weightWhole: Int
    @State private var weightTenth: Int
    @State private var weightHundredth: Int
    @State private var logMeal: Bool
    @State private var mealGrams: Int
    @State private var confirmingDelete = false

    private static let maxPoop = 20
    private static let mealStep = 5
    private static let maxMeal = 1000

    init(petID: String, day: Date, existing: HealthRecord?, suggestedWeight: Double?) {
        self.petID = petID
        self.day = day
        self.existing = existing

        _logPoop = State(initialValue: existing?.poopRecorded ?? false)
        _poop = State(initialValue: existing?.poopCount ?? 0)
        _extra = State(initialValue: HealthExtraInput(record: existing))

        // 몸무게를 정수 부분과 소수 두 자리로 나눕니다. (예: 4.25 → 4 와 2 와 5)
        let weight = existing?.weightKg ?? suggestedWeight ?? 5.0
        let total = min(Int((weight * 100).rounded()), 9999)    // 0.01kg 단위로 계산
        _weightWhole = State(initialValue: total / 100)
        _weightTenth = State(initialValue: (total % 100) / 10)
        _weightHundredth = State(initialValue: total % 10)
        _logWeight = State(initialValue: existing?.weightKg != nil)

        // 식사량은 5의 배수로 맞춥니다.
        let meal = existing?.mealGrams ?? 100
        _mealGrams = State(initialValue: min((meal / Self.mealStep) * Self.mealStep, Self.maxMeal))
        _logMeal = State(initialValue: existing?.mealGrams != nil)
    }

    private var petName: String { notebook.pets.first { $0.id == petID }?.name ?? "" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Text(day.formatted(date: .long, time: .omitted))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)

                    poopCard
                    weightCard
                    mealCard
                    HealthExtraFields(input: $extra)

                    if existing != nil {
                        Button("기록 삭제", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("\(petName)의 건강 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장", action: save) }
            }
            .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { delete() }
            }
        }
    }

    // MARK: 응가 (횟수)

    private var poopCard: some View {
        card("응가 횟수") {
            Toggle("응가 횟수 기록하기", isOn: $logPoop)
                .tint(AppTheme.buttonShadow)
            if logPoop {
                HStack(spacing: 24) {
                    Spacer()
                    Button {
                        poop = max(0, poop - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 40))
                    }
                    .accessibilityLabel("응가 횟수 줄이기")
                    .disabled(poop == 0)

                    Text("\(poop)")
                        .font(AppTheme.Typography.counterNumber)
                        .foregroundStyle(AppTheme.text)
                        .frame(minWidth: 60)

                    Button {
                        poop = min(Self.maxPoop, poop + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 40))
                    }
                    .accessibilityLabel("응가 횟수 늘리기")
                    .disabled(poop == Self.maxPoop)
                    Spacer()
                }
                .foregroundStyle(AppTheme.softButtonText)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 몸무게 (kg, 소수점 둘째 자리)

    private var weightCard: some View {
        card("몸무게 (kg)") {
            Toggle("몸무게 기록하기", isOn: $logWeight)
                .tint(AppTheme.buttonShadow)
            if logWeight {
                HStack(spacing: 0) {
                    Picker("몸무게", selection: $weightWhole) {
                        ForEach(0...99, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 90, height: 110)
                    .clipped()

                    Text(".").font(AppTheme.Typography.title)

                    Picker("소수점 첫째 자리", selection: $weightTenth) {
                        ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 110)
                    .clipped()

                    Picker("소수점 둘째 자리", selection: $weightHundredth) {
                        ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 110)
                    .clipped()

                    Text("kg").font(AppTheme.Typography.headline).padding(.leading, 6)
                }
                .frame(maxWidth: .infinity)
                Text("소수점 둘째 자리까지 고를 수 있어요")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
        }
    }

    // MARK: 식사량 (g, 5 단위)

    private var mealCard: some View {
        card("식사량 (g, 5g 단위)") {
            Toggle("식사량 기록하기", isOn: $logMeal)
                .tint(AppTheme.buttonShadow)
            if logMeal {
                Picker("식사량", selection: $mealGrams) {
                    ForEach(Array(stride(from: 0, through: Self.maxMeal, by: Self.mealStep)), id: \.self) { grams in
                        Text("\(grams) g").tag(grams)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
                .clipped()
            }
        }
    }

    private func card<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            content()
        }
        .foregroundStyle(AppTheme.text)
        .padding(AppTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    // MARK: 저장·삭제

    private func save() {
        guard let user = session.currentUser, Permissions.canEditHealthRecords(user) else { return }
        var record = HealthRecord(
            id: existing?.id ?? UUID().uuidString,
            petID: petID,
            date: Calendar.current.startOfDay(for: day),
            poopCount: logPoop ? poop : 0,
            weightKg: logWeight ? Double(weightWhole * 100 + weightTenth * 10 + weightHundredth) / 100 : nil,
            mealGrams: logMeal ? mealGrams : nil,
            recordedByID: user.id,
            poopRecorded: logPoop
        )
        extra.apply(to: &record, keepExisting: false)
        health.save(record)
        dismiss()
    }

    private func delete() {
        guard let user = session.currentUser, Permissions.canEditHealthRecords(user),
              let existing else { return }
        health.delete(id: existing.id)
        dismiss()
    }
}

#Preview("새 기록") {
    HealthRecordEditorView(petID: "pet-bori", day: .now, existing: nil, suggestedWeight: 4.2)
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
}

#Preview("기록 수정 (다크)") {
    HealthRecordEditorView(petID: "pet-bori", day: .now,
                           existing: HealthRecord.samples().first, suggestedWeight: nil)
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
        .preferredColorScheme(.dark)
}
