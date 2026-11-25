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
    var isDefault: Bool {
        var defaults = AppSettings()
        defaults.pushEnabled = settings.pushEnabled
        return settings == defaults
    }

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

    var pushEnabled: Bool { settings.pushEnabled }

    /// 기기 알림 켜기/끄기. 켤 때 iOS 권한을 요청하고, 거절되면 꺼진 채로 두고 false를 돌려줘요.
    @discardableResult
    func setPushEnabled(_ enabled: Bool) async -> Bool {
        var result = enabled
        if enabled {
            result = await DevicePushService.shared.requestAuthorization()
        } else {
            DevicePushService.shared.clearAll()
        }
        settings.pushEnabled = result
        service.save(settings)
        return result == enabled
    }

    /// iOS 설정 앱에서 알림을 꺼 버렸다면 앱 스위치도 함께 끕니다.
    func syncPushWithSystem() async {
        guard settings.pushEnabled, !(await DevicePushService.shared.isAuthorized()) else { return }
        settings.pushEnabled = false
        service.save(settings)
    }

    func reset() {
        let push = settings.pushEnabled     // 화면 설정 되돌리기가 알림 설정을 끄지는 않아요.
        settings = AppSettings()
        settings.pushEnabled = push
        AppFontSelection.shared.style = .system
        service.save(settings)
    }
}
