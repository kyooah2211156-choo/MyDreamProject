import Foundation

/// 유치원 이름을 저장하고 불러오는 약속.
/// 지금은 기기에 저장하고, 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol KindergartenNameStoring {
    func load() -> String?
    func save(_ name: String)
}

/// 기기 안(UserDefaults)에 저장 — 앱을 껐다 켜도 이름이 남습니다.
struct UserDefaultsKindergartenNameStore: KindergartenNameStoring {
    private let key = "kindergartenName"

    func load() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    func save(_ name: String) {
        UserDefaults.standard.set(name, forKey: key)
    }
}

/// 저장하지 않는 버전 — 미리보기(Preview)와 테스트용
struct InMemoryKindergartenNameStore: KindergartenNameStoring {
    func load() -> String? { nil }
    func save(_ name: String) {}
}
