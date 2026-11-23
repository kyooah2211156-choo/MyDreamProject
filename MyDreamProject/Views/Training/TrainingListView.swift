import SwiftUI

/// 훈련 목록: 카드마다 제목, 난이도, 진행도가 보여요. 누르면 상세 화면으로 갑니다.
struct TrainingListView: View {
    @State private var trainings: [Training]

    init(service: TrainingService = FakeTrainingService()) {
        _trainings = State(initialValue: service.loadTrainings())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.medium) {
                    ForEach(trainings) { training in
                        NavigationLink {
                            TrainingDetailView(training: training)
                        } label: {
                            card(training)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("훈련")
        }
    }

    private func card(_ training: Training) -> some View {
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
                HStack(spacing: 8) {
                    ProgressView(value: training.progress)
                        .tint(AppTheme.buttonShadow)
                    Text("\(Int(training.progress * 100))%")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
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

#Preview("라이트") {
    TrainingListView()
}

#Preview("다크") {
    TrainingListView()
        .preferredColorScheme(.dark)
}
