import SwiftUI

/// 훈련 상세: 진행도, 훈련 순서, 선생님 팁
struct TrainingDetailView: View {
    let training: Training

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header
                progressCard
                stepsCard
                tipCard
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(training.title)
        .navigationBarTitleDisplayMode(.inline)
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

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("진행도").font(AppTheme.Typography.headline)
                Spacer()
                Text("\(Int(training.progress * 100))%")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.softButtonText)
            }
            .foregroundStyle(AppTheme.text)
            ProgressView(value: training.progress)
                .tint(AppTheme.buttonShadow)
        }
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .accessibilityElement(children: .combine)
    }

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

#Preview("라이트") {
    NavigationStack { TrainingDetailView(training: Training.samples[0]) }
}

#Preview("다크") {
    NavigationStack { TrainingDetailView(training: Training.samples[3]) }
        .preferredColorScheme(.dark)
}
