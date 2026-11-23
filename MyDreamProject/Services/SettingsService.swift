import Foundation

/// 앱 설정을 저장하고 불러오는 약속.
/// 지금은 이 기기에만 저장하고, 나중에 계정에 묶어 서버에 저장하려면 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol SettingsService {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

/// 기기 안(UserDefaults)에 저장 — 앱을 껐다 켜도 설정이 남아요.
struct UserDefaultsSettingsService: SettingsService {
    private let key = "appSettings"

    func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// 저장하지 않는 버전 — 미리보기(Preview)와 테스트용
struct InMemorySettingsService: SettingsService {
    func load() -> AppSettings { AppSettings() }
    func save(_ settings: AppSettings) {}
}
