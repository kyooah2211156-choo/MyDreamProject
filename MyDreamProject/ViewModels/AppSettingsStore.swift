import Foundation
import Observation

/// 앱 설정(화면 모드, 글씨 크기)을 들고 있고, 바꾸면 저장합니다.
@Observable
final class AppSettingsStore {
    private let service: SettingsService
    private(set) var settings: AppSettings

    init(service: SettingsService = UserDefaultsSettingsService()) {
        self.service = service
        let loaded = service.load()
        self.settings = loaded
        AppFontSelection.shared.style = loaded.fontStyle
    }

    var appearance: AppearanceMode { settings.appearance }
    var textSize: TextSizeOption { settings.textSize }
    var fontStyle: AppFontStyle { settings.fontStyle }

    /// 기본값(시스템 설정)과 같은지
    var isDefault: Bool { settings == AppSettings() }

    func setAppearance(_ appearance: AppearanceMode) {
        settings.appearance = appearance
        service.save(settings)
    }

    func setTextSize(_ textSize: TextSizeOption) {
        settings.textSize = textSize
        service.save(settings)
    }

    func setFontStyle(_ fontStyle: AppFontStyle) {
        settings.fontStyle = fontStyle
        AppFontSelection.shared.style = fontStyle
        service.save(settings)
    }

    func reset() {
        settings = AppSettings()
        AppFontSelection.shared.style = .system
        service.save(settings)
    }
}
