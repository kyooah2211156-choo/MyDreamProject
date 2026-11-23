import SwiftUI

/// 설정 화면: 화면 모드(시스템·라이트·다크), 글씨 크기, 미리보기
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettingsStore.self) private var settings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    appearanceCard
                    textSizeCard
                    fontCard
                    previewCard

                    Button("기본값으로 되돌리기") { settings.reset() }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(settings.isDefault)

                    Text("이 설정은 이 기기에만 저장돼요.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
    }

    // MARK: 화면 모드

    private var appearanceCard: some View {
        card("화면 모드") {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                optionRow(title: mode.displayName, symbol: mode.symbol,
                          isOn: settings.appearance == mode) {
                    settings.setAppearance(mode)
                }
            }
        }
    }

    // MARK: 글씨 크기

    private var textSizeCard: some View {
        card("글씨 크기") {
            ForEach(TextSizeOption.allCases, id: \.self) { option in
                optionRow(title: option.displayName, symbol: nil,
                          isOn: settings.textSize == option) {
                    settings.setTextSize(option)
                }
            }
        }
    }

    // MARK: 글꼴 (각 줄은 그 글꼴로 보여줘요)

    private var fontCard: some View {
        card("글꼴") {
            ForEach(AppFontStyle.allCases, id: \.self) { style in
                fontRow(style)
            }
            Text("무료 글꼴(SIL Open Font License)을 사용해요.")
                .font(AppTheme.Typography.captionRegular)
                .foregroundStyle(AppTheme.subText)
                .padding(.top, 4)
        }
    }

    private func fontRow(_ style: AppFontStyle) -> some View {
        let isOn = settings.fontStyle == style
        return Button {
            settings.setFontStyle(style)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(AppFont.font(style: style, textStyle: .body, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    if let credit = style.credit {
                        Text(verbatim: credit)
                            .font(AppFont.font(style: style, textStyle: .caption, weight: .regular))
                            .foregroundStyle(AppTheme.subText)
                    }
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? AppTheme.statusApproved : AppTheme.subText)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(isOn ? AppTheme.softButton : Color.clear, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: 미리보기 (고른 설정이 바로 적용된 모습)

    private var previewCard: some View {
        card("미리보기") {
            Text("오늘도 보리가 신나게 뛰어놀았어요! 🐾")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.text)
            Text("댕답개 배우개")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
        }
    }

    // MARK: 공통 조각

    private func card<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    private func optionRow(title: String, symbol: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(AppTheme.softButtonText)
                        .frame(width: 28)
                }
                Text(title)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? AppTheme.statusApproved : AppTheme.subText)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(isOn ? AppTheme.softButton : Color.clear, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview("라이트") {
    SettingsView()
        .environment(AppSettingsStore(service: InMemorySettingsService()))
}

#Preview("다크") {
    SettingsView()
        .environment(AppSettingsStore(service: InMemorySettingsService()))
        .preferredColorScheme(.dark)
}
