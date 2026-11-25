import SwiftUI

/// 훈련 목록: 반려견을 고르면 그 아이의 진행도가 카드에 보여요. 누르면 상세 화면으로 갑니다.
/// (원장·선생님은 승인된 반려견 전체, 보호자는 내 반려견만 고를 수 있어요)
struct TrainingListView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(TrainingProgressStore.self) private var progress
    /// 반려견별로 추가한 훈련 항목 (없는 곳에서는 기본 훈련만 보여요)
    @Environment(PetDetailStore.self) private var petDetails: PetDetailStore?
    /// 오늘 등원 정보 (원장·선생님 화면에서만 있어요)
    @Environment(TeacherHomeViewModel.self) private var attendance: TeacherHomeViewModel?
    @State private var trainings: [Training]
    @State private var selectedPetID: String?
    @State private var addingTraining = false

    init(service: TrainingService = FakeTrainingService()) {
        _trainings = State(initialValue: service.loadTrainings())
    }

    var body: some View {
        NavigationStack {
            if let user = session.currentUser {
                content(for: user)
            }
        }
    }

    private func content(for user: User) -> some View {
        let pets = TeacherHomeViewModel.todaysPets(notebook.visiblePets(for: user), for: user, attendance: attendance)
        let selected = pets.first { $0.id == selectedPetID } ?? pets.first
        return ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.medium) {
                petChips(pets, selected: selected)
                ForEach(trainings + customTrainings(for: selected?.id)) { training in
                    NavigationLink {
                        TrainingDetailView(training: training, petID: selected?.id)
                    } label: {
                        card(training, petID: selected?.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("훈련")
        .toolbar {
            // 원장·선생님은 고른 반려견에게만 보이는 훈련 항목을 추가할 수 있어요.
            ToolbarItem(placement: .topBarTrailing) {
                if Permissions.canManageTrainingPlan(user), selected != nil, petDetails != nil {
                    Button { addingTraining = true } label: {
                        Image(systemName: "plus").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("훈련 항목 추가")
                }
            }
        }
        .sheet(isPresented: $addingTraining) {
            if let selected { CustomTrainingEditorView(petID: selected.id, existing: nil) }
        }
    }

    private func customTrainings(for petID: String?) -> [Training] {
        guard let petID, let petDetails else { return [] }
        return petDetails.customTrainings(petID: petID).map(\.asTraining)
    }

    // MARK: 반려견 고르기

    @ViewBuilder
    private func petChips(_ pets: [Pet], selected: Pet?) -> some View {
        if pets.isEmpty {
            let isStaff = session.currentUser?.role == .owner || session.currentUser?.role == .teacher
            let message: LocalizedStringKey = isStaff && attendance != nil
                ? "오늘 등원한 반려견이 없어요" : "승인된 반려견이 없어요"
            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.small) {
                    ForEach(pets) { pet in
                        let isOn = pet.id == selected?.id
                        Button {
                            selectedPetID = pet.id
                        } label: {
                            Text(pet.name)
                                .font(AppTheme.Typography.headline)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                                .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton),
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 훈련 카드

    private func card(_ training: Training, petID: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: training.symbol)
                .font(.title2)
                .foregroundStyle(AppTheme.softButtonText)
                .frame(width: 52, height: 52)
                .background(AppTheme.avatar, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(training.title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.text)
                    DifficultyBadge(difficulty: training.difficulty)
                }
                Text(training.summary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                    .lineLimit(1)
                if let petID {
                    let percent = progress.percent(petID: petID, trainingID: training.id)
                    HStack(spacing: 8) {
                        ProgressView(value: Double(percent), total: 100)
                            .tint(AppTheme.buttonShadow)
                        Text("\(percent)%")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.subText)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }
}

/// 난이도 배지 (초급 초록 / 중급 주황 / 고급 빨강)
struct DifficultyBadge: View {
    let difficulty: TrainingDifficulty

    private var color: Color {
        switch difficulty {
        case .beginner: AppTheme.statusApproved
        case .intermediate: AppTheme.statusPending
        case .advanced: AppTheme.statusRejected
        }
    }

    var body: some View {
        Text(difficulty.displayName)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

#Preview("선생님") {
    TrainingListView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(TrainingProgressStore())
}

#Preview("보호자 (다크)") {
    TrainingListView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(TrainingProgressStore())
        .preferredColorScheme(.dark)
}
