import SwiftUI

/// 개인정보 수집·이용 안내 카드 (보호자 가입 화면과 운영규칙 보기에서 사용)
struct PrivacyConsentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Label(PrivacyConsent.title, systemImage: "lock.shield.fill")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            ForEach(PrivacyConsent.sections) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.softButtonText)
                    ForEach(section.lines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(AppTheme.subText)
                            Text(line)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.text)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }
}

#Preview("라이트") {
    ScrollView { PrivacyConsentView().padding() }
        .background(AppTheme.background)
}

#Preview("다크") {
    ScrollView { PrivacyConsentView().padding() }
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}
