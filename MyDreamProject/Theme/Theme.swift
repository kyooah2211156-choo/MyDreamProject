import SwiftUI
import UIKit

/// 앱 전체의 디자인 규칙을 모아 둔 곳 (시안 4번 "몽글 라벤더").
/// 색, 글자 크기, 간격, 둥글기, 버튼 모양을 바꾸고 싶으면 이 파일만 고치면 됩니다.
/// 라이트/다크 모드에 맞춰 색이 자동으로 바뀝니다.
enum AppTheme {
    // MARK: 색 만들기 도우미

    nonisolated private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// 라이트 모드 색과 다크 모드 색을 한 번에 지정
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
        })
    }

    // MARK: 글자·바탕

    static let text = dynamic(light: 0x3E2A5C, dark: 0xF1E8FF)
    static let subText = dynamic(light: 0x8C79A8, dark: 0xB3A2CF)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x2B2145)
    static let track = dynamic(light: 0xE6D9FB, dark: 0x41336A)
    static let cardShadow = dynamic(light: 0x9669E6, dark: 0x000000).opacity(0.22)

    static let background = LinearGradient(
        colors: [dynamic(light: 0xF7F1FF, dark: 0x1D1530),
                 dynamic(light: 0xECDFFF, dark: 0x130D21)],
        startPoint: .top, endPoint: .bottom
    )

    static let hero = LinearGradient(
        colors: [dynamic(light: 0xA77BFF, dark: 0x6A45C9),
                 dynamic(light: 0xC58BFF, dark: 0x8A52C9),
                 dynamic(light: 0xFF9AD0, dark: 0xB9548F)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let avatar = LinearGradient(
        colors: [dynamic(light: 0xE2D1FF, dark: 0x4A3A7A),
                 dynamic(light: 0xFBE3F2, dark: 0x3B2D62)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // MARK: 버튼

    static let button = LinearGradient(
        colors: [dynamic(light: 0x9A6CF5, dark: 0xB794FF),
                 dynamic(light: 0xFF8CC6, dark: 0xFF9ED0)],
        startPoint: .leading, endPoint: .trailing
    )
    static let buttonText = dynamic(light: 0xFFFFFF, dark: 0x241540)
    static let buttonShadow = dynamic(light: 0x7A50CF, dark: 0x7F60C4)
    static let softButton = dynamic(light: 0xEFE4FF, dark: 0x41336A)
    static let softButtonText = dynamic(light: 0x7A4FD0, dark: 0xD7C3FF)

    // MARK: 상태 배지 색 (반려견 등록 상태 등)

    static let statusPending = dynamic(light: 0xE08A1E, dark: 0xFFB454)
    static let statusApproved = dynamic(light: 0x4E9A1F, dark: 0x8CD13F)
    static let statusRejected = dynamic(light: 0xE0544F, dark: 0xFF8585)

    // MARK: 글자 (시스템 둥근 글꼴 사용, 글자 크기 설정을 따라감)

    enum Typography {
        static var largeTitle: Font { AppFont.font(.largeTitle, weight: .black) }
        static var title: Font { AppFont.font(.title2, weight: .heavy) }
        static var headline: Font { AppFont.font(.headline, weight: .semibold) }
        static var body: Font { AppFont.font(.body, weight: .regular) }
        static var caption: Font { AppFont.font(.caption, weight: .semibold) }

        static var heroTitle: Font { AppFont.font(.title, weight: .black) }
        static var title3Heavy: Font { AppFont.font(.title3, weight: .heavy) }
        static var subheadline: Font { AppFont.font(.subheadline, weight: .regular) }
        static var subheadlineBold: Font { AppFont.font(.subheadline, weight: .bold) }
        static var buttonLabel: Font { AppFont.font(.subheadline, weight: .heavy) }
        static var footnoteBold: Font { AppFont.font(.footnote, weight: .bold) }
        static var captionRegular: Font { AppFont.font(.caption, weight: .regular) }
        static var captionBold: Font { AppFont.font(.caption, weight: .bold) }
        static var caption2: Font { AppFont.font(.caption2, weight: .regular) }
        static var caption2Bold: Font { AppFont.font(.caption2, weight: .bold) }
        static var statNumber: Font { AppFont.sized(44, weight: .black, relativeTo: .largeTitle) }
        static var counterNumber: Font { AppFont.sized(40, weight: .black, relativeTo: .largeTitle) }
    }

    // MARK: 간격과 둥글기

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let screen: CGFloat = 20
    }

    enum Radius {
        static let button: CGFloat = 16
        static let card: CGFloat = 22
        static let hero: CGFloat = 34
    }
}

/// 주요 버튼 (그라데이션 + 눌리는 느낌의 그림자)
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.buttonLabel)
            .foregroundStyle(AppTheme.buttonText)
            .frame(maxWidth: .infinity, minHeight: 48)
            // 입체감을 주는 그림자는 배경 모양에만 붙입니다. (글자와 아이콘에 붙으면 글자가 겹쳐 보여요)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.button)
                    .shadow(color: AppTheme.buttonShadow, radius: 0, x: 0, y: configuration.isPressed ? 1 : 4)
            }
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 보조 버튼 (연한 배경)
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.buttonLabel)
            .foregroundStyle(AppTheme.softButtonText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(AppTheme.softButton, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
