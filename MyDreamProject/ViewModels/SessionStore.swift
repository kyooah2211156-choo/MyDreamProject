import Foundation
import Observation

/// 지금 로그인한 사람이 누구인지 앱 전체가 함께 보는 곳.
/// 앱 맨 위에서 한 번 만들고, 모든 화면이 꺼내 씁니다.
@Observable
final class SessionStore {
    private(set) var currentUser: User?
    private(set) var isLoading = false
    var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService = FakeAuthService(), currentUser: User? = nil) {
        self.authService = authService
        self.currentUser = currentUser
    }

    var isLoggedIn: Bool { currentUser != nil }
    var role: Role? { currentUser?.role }

    func login(id: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            currentUser = try await authService.login(id: id, password: password)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "로그인에 실패했어요."
        }
    }

    /// 보호자 가입. 성공하면 만들어진 사용자를 돌려주고, 로그인은 따로 합니다.
    func register(name: String, id: String, password: String) async -> User? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await authService.register(name: name, id: id, password: password)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "가입에 실패했어요."
            return nil
        }
    }

    func logout() {
        authService.logout()
        currentUser = nil
        errorMessage = nil
    }
}
