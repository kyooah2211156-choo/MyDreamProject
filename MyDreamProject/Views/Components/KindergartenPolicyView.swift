import SwiftUI

/// 유치원 철학과 운영규칙을 보여주는 카드 (보호자 가입 화면에서 사용)
struct KindergartenPolicyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            philosophyCard
            rulesCard
        }
    }

    private var philosophyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(KindergartenPolicy.philosophyTitle, systemImage: "heart.fill")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.white)
            ForEach(KindergartenPolicy.philosophy, id: \.self) { line in
                Text(line)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.hero, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(KindergartenPolicy.rulesTitle, systemImage: "checkmark.shield.fill")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            Text(KindergartenPolicy.rulesIntro)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
            ForEach(KindergartenPolicy.ruleItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.softButtonText)
                        .padding(.top, 4)
                    Text(item)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.text)
                }
            }
            Text(KindergartenPolicy.rulesNotice)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.statusRejected)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }
}

#Preview("라이트") {
    ScrollView { KindergartenPolicyView().padding() }
        .background(AppTheme.background)
}

#Preview("다크") {
    ScrollView { KindergartenPolicyView().padding() }
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}
