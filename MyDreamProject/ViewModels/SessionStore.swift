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

    init(authService: AuthService = FakeAuthService.shared, currentUser: User? = nil) {
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

    /// 회원가입. 성공하면 만들어진 사용자를 돌려주고, 로그인은 따로 합니다.
    func register(name: String, id: String, password: String, role: Role, inviteCode: String = "") async -> User? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await authService.register(name: name, id: id, password: password, role: role, inviteCode: inviteCode)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "가입에 실패했어요."
            return nil
        }
    }

    /// 로그인 중인 계정이 아직 이용 가능한지 확인합니다.
    /// 퇴사 처리나 이용 중단이 되면 바로 로그아웃시키고, 이유를 로그인 화면에 보여줍니다.
    /// (서버를 붙이면 서버가 알려주는 방식으로 바뀌어요)
    func validateSession() {
        guard let user = currentUser,
              let status = authService.accountStatus(of: user.id),
              let error = LoginError.blocking(status) else { return }
        authService.logout()
        currentUser = nil
        errorMessage = error.errorDescription
    }

    func logout() {
        authService.logout()
        currentUser = nil
        errorMessage = nil
    }
}
