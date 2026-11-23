import SwiftUI

/// 훈련 진행도 입력 화면 (원장·선생님): 진행도(10% 단위), 날짜, 메모(선택)
struct TrainingProgressEditorView: View {
    let petID: String
    let training: Training
    let existing: TrainingProgress?

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(TrainingProgressStore.self) private var progress

    @State private var percent: Int
    @State private var day: Date
    @State private var memo: String
    @State private var confirmingDelete = false

    init(petID: String, training: Training, day: Date, existing: TrainingProgress?, suggestedPercent: Int) {
        self.petID = petID
        self.training = training
        self.existing = existing
        _percent = State(initialValue: existing?.percent ?? suggestedPercent)
        _day = State(initialValue: Calendar.current.startOfDay(for: day))
        _memo = State(initialValue: existing?.memo ?? "")
    }

    private var petName: String { notebook.pets.first { $0.id == petID }?.name ?? "" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Text("\(petName) · \(training.title)")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.text)

                    card("진행도 (10% 단위)") {
                        Picker("진행도", selection: $percent) {
                            ForEach(Array(stride(from: 0, through: 100, by: 10)), id: \.self) { value in
                                Text("\(value)%").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 110)
                        .clipped()
                    }

                    card("날짜") {
                        DatePicker("날짜", selection: $day, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    card("메모 (선택)") {
                        TextField("예: 손을 올릴 때 아직 망설여요", text: $memo, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if existing != nil {
                        Button("기록 삭제", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("진행도 기록")
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

    private func save() {
        guard let user = session.currentUser, Permissions.canEditTrainingProgress(user) else { return }
        progress.save(TrainingProgress(
            id: existing?.id ?? UUID().uuidString,
            petID: petID,
            trainingID: training.id,
            percent: percent,
            date: Calendar.current.startOfDay(for: day),
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            recordedByID: user.id
        ))
        dismiss()
    }

    private func delete() {
        guard let user = session.currentUser, Permissions.canEditTrainingProgress(user),
              let existing else { return }
        progress.delete(id: existing.id)
        dismiss()
    }
}

#Preview("새 기록") {
    TrainingProgressEditorView(petID: "pet-bori", training: Training.samples[0], day: .now,
                               existing: nil, suggestedPercent: 90)
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(TrainingProgressStore())
}

#Preview("기록 수정 (다크)") {
    TrainingProgressEditorView(petID: "pet-bori", training: Training.samples[0], day: .now,
                               existing: TrainingProgress.samples().first, suggestedPercent: 0)
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(TrainingProgressStore())
        .preferredColorScheme(.dark)
}
