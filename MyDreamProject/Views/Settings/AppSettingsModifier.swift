import SwiftUI

extension AppearanceMode {
    /// nil이면 기기 설정을 따라갑니다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

extension TextSizeOption {
    /// nil이면 기기의 글자 크기 설정을 따라갑니다.
    /// 화면이 깨지지 않도록 '접근성용 초대형' 단계 아래까지만 키워요.
    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .system: nil
        case .small: .small
        case .standard: .large
        case .large: .xxLarge
        case .extraLarge: .xxxLarge
        }
    }
}

/// 고른 화면 모드와 글씨 크기를 앱 전체에 적용합니다. (앱 맨 위에서 한 번만 붙여요)
struct AppSettingsModifier: ViewModifier {
    let settings: AppSettings

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(settings.appearance.colorScheme)
            .transformEnvironment(\.dynamicTypeSize) { size in
                if let override = settings.textSize.dynamicTypeSize {
                    size = override
                }
            }
    }
}

extension View {
    func appSettings(_ settings: AppSettings) -> some View {
        modifier(AppSettingsModifier(settings: settings))
    }
}
