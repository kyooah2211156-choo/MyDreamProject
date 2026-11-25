import Foundation

/// 화면 모드: 기기 설정을 따르거나, 라이트·다크로 고정
enum AppearanceMode: String, Codable, CaseIterable, Hashable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: String(localized: "시스템 설정")
        case .light: String(localized: "라이트")
        case .dark: String(localized: "다크")
        }
    }
}

/// 글씨 크기: 기기 설정을 따르거나, 이 앱만 4단계 중에서 고정
enum TextSizeOption: String, Codable, CaseIterable, Hashable {
    case system
    case small
    case standard
    case large
    case extraLarge

    var displayName: String {
        switch self {
        case .system: String(localized: "기기 설정 따름")
        case .small: String(localized: "작게")
        case .standard: String(localized: "보통")
        case .large: String(localized: "크게")
        case .extraLarge: String(localized: "아주 크게")
        }
    }
}

/// 글꼴: 기본(시스템) 또는 앱에 넣은 무료 글꼴 3가지 (모두 SIL Open Font License)
enum AppFontStyle: String, Codable, CaseIterable, Hashable {
    case system
    case round      // 둥글고 귀여운 (주아)
    case gothic     // 또렷한 고딕 (나눔고딕)
    case serif      // 명조 (나눔명조)

    var displayName: String {
        switch self {
        case .system: String(localized: "기본 글꼴")
        case .round: String(localized: "둥글고 귀여운")
        case .gothic: String(localized: "또렷한 고딕")
        case .serif: String(localized: "명조")
        }
    }
}

/// 사용자가 고른 앱 설정 (이 기기에만 저장)
struct AppSettings: Codable, Equatable {
    var appearance: AppearanceMode = .system
    var textSize: TextSizeOption = .system
    var fontStyle: AppFontStyle = .system
    var pushEnabled: Bool = false           // 기기 알림 켜기/끄기

    init() {}

    private enum CodingKeys: String, CodingKey {
        case appearance, textSize, fontStyle, pushEnabled
    }

    /// 예전에 저장된 설정(글꼴 항목이 없는)도 그대로 읽을 수 있게 합니다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
        textSize = try container.decodeIfPresent(TextSizeOption.self, forKey: .textSize) ?? .system
        fontStyle = try container.decodeIfPresent(AppFontStyle.self, forKey: .fontStyle) ?? .system
        pushEnabled = try container.decodeIfPresent(Bool.self, forKey: .pushEnabled) ?? false
    }
}
