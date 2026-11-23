import Foundation

/// 로그인·가입에 실패한 이유
enum LoginError: LocalizedError {
    case emptyField
    case unknownAccount
    case duplicateID
    case shortPassword

    var errorDescription: String? {
        switch self {
        case .emptyField: "아이디와 비밀번호를 모두 입력해 주세요."
        case .unknownAccount: "등록되지 않은 아이디예요. 샘플 계정 버튼을 눌러 보세요."
        case .duplicateID: "이미 사용 중인 아이디예요."
        case .shortPassword: "비밀번호는 4자 이상 입력해 주세요."
        }
    }
}

/// 로그인/가입/로그아웃을 담당하는 약속.
/// 서버(Firebase 등)를 붙일 때는 이 약속을 따르는 새 클래스를 만들어 바꿔 끼우면 됩니다.
protocol AuthService {
    func login(id: String, password: String) async throws -> User
    /// 보호자 가입. 계정만 만들고, 로그인은 따로 합니다.
    func register(name: String, id: String, password: String) async throws -> User
    func logout()
}

/// 연습용 가짜 로그인. 아이디에 따라 미리 만든 샘플 사용자로 들어갑니다.
/// 비밀번호는 비어 있지만 않으면 통과합니다. (가입한 계정도 앱을 끄면 사라져요)
final class FakeAuthService: AuthService {
    private var accounts: [String: User] = [
        "owner": SampleData.owner,
        "teacher": SampleData.teacher,
        "parent": SampleData.parent,
        "parent2": SampleData.otherParent
    ]

    private func clean(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func login(id: String, password: String) async throws -> User {
        let cleanID = clean(id)
        guard !cleanID.isEmpty, !password.isEmpty else { throw LoginError.emptyField }

        // 서버에 물어보는 것처럼 잠깐 기다립니다.
        try? await Task.sleep(for: .milliseconds(300))

        guard let user = accounts[cleanID] else { throw LoginError.unknownAccount }
        return user
    }

    func register(name: String, id: String, password: String) async throws -> User {
        let cleanID = clean(id)
        guard !cleanID.isEmpty, !password.isEmpty else { throw LoginError.emptyField }
        guard password.count >= 4 else { throw LoginError.shortPassword }

        try? await Task.sleep(for: .milliseconds(300))

        guard accounts[cleanID] == nil else { throw LoginError.duplicateID }
        let user = User(id: "user-" + UUID().uuidString,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        role: .parent)
        accounts[cleanID] = user
        return user
    }

    func logout() {}
}
