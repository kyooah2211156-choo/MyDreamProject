import SwiftUI

/// 훈련 상세: 고른 반려견의 진행도와 기록, 훈련 순서, 선생님 팁
struct TrainingDetailView: View {
    let training: Training
    let petID: String?

    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(TrainingProgressStore.self) private var progress
    @State private var editorTarget: EditorTarget?

    private struct EditorTarget: Identifiable {
        let day: Date
        var id: TimeInterval { day.timeIntervalSince1970 }
    }

    private var petName: String? { notebook.pets.first { $0.id == petID }?.name }
    private var canEdit: Bool {
        guard let user = session.currentUser else { return false }
        return Permissions.canEditTrainingProgress(user)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header
                if let petID {
                    progressCard(petID)
                    historyCard(petID)
                }
                stepsCard
                tipCard
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(training.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editorTarget) { target in
            if let petID {
                TrainingProgressEditorView(
                    petID: petID,
                    training: training,
                    day: target.day,
                    existing: progress.record(petID: petID, trainingID: training.id, on: target.day),
                    suggestedPercent: progress.percent(petID: petID, trainingID: training.id)
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: training.symbol)
                .font(.largeTitle)
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(AppTheme.hero, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(training.title)
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.text)
                    DifficultyBadge(difficulty: training.difficulty)
                }
                Text(training.summary)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
            }
        }
    }

    // MARK: 이 반려견의 진행도

    private func progressCard(_ petID: String) -> some View {
        let percent = progress.percent(petID: petID, trainingID: training.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(petName ?? "")의 진행도").font(AppTheme.Typography.headline)
                Spacer()
                Text("\(percent)%")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.softButtonText)
            }
            .foregroundStyle(AppTheme.text)
            ProgressView(value: Double(percent), total: 100)
                .tint(AppTheme.buttonShadow)
            if canEdit {
                Button("진행도 기록하기") {
                    editorTarget = EditorTarget(day: Calendar.current.startOfDay(for: .now))
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    private func historyCard(_ petID: String) -> some View {
        let history = progress.history(petID: petID, trainingID: training.id)
        return VStack(alignment: .leading, spacing: 10) {
            Text("진행 기록")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            if history.isEmpty {
                Text("아직 기록이 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
            }
            ForEach(history) { item in
                historyRow(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    @ViewBuilder
    private func historyRow(_ item: TrainingProgress) -> some View {
        if canEdit {
            Button { editorTarget = EditorTarget(day: item.date) } label: { historyRowContent(item, editable: true) }
                .buttonStyle(.plain)
        } else {
            historyRowContent(item, editable: false)
        }
    }

    private func historyRowContent(_ item: TrainingProgress, editable: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.date.formatted(.dateTime.month().day()))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
                .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.percent)%")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                if !item.memo.isEmpty {
                    Text(item.memo)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
            }
            Spacer(minLength: 0)
            if editable {
                Image(systemName: "pencil")
                    .foregroundStyle(AppTheme.softButtonText)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
    }

    // MARK: 훈련 순서·팁

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("훈련 순서")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            ForEach(Array(training.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.buttonText)
                        .frame(width: 26, height: 26)
                        .background(AppTheme.button, in: Circle())
                    Text(step)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.text)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    private var tipCard: some View {
        Label(training.tip, systemImage: "lightbulb.fill")
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.softButtonText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.large)
            .background(AppTheme.softButton, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}

#Preview("선생님 (기록 가능)") {
    NavigationStack { TrainingDetailView(training: Training.samples[0], petID: "pet-bori") }
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(TrainingProgressStore())
}

#Preview("보호자 (보기만, 다크)") {
    NavigationStack { TrainingDetailView(training: Training.samples[3], petID: "pet-bori") }
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(TrainingProgressStore())
        .preferredColorScheme(.dark)
}
