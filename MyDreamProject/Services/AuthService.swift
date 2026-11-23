import Foundation

/// 로그인·가입에 실패한 이유
enum LoginError: LocalizedError {
    case emptyField
    case invalidCredentials
    case duplicateID
    case shortPassword
    case invalidInvite
    case notAllowed
    case pendingApproval
    case accountRejected
    case accountResigned
    case accountSuspended

    var errorDescription: String? {
        switch self {
        case .emptyField: String(localized: "아이디와 비밀번호를 모두 입력해 주세요.")
        case .invalidCredentials: String(localized: "아이디 또는 비밀번호가 맞지 않아요.")
        case .duplicateID: String(localized: "이미 사용 중인 아이디예요.")
        case .shortPassword: String(localized: "비밀번호는 4자 이상 입력해 주세요.")
        case .invalidInvite: String(localized: "초대 코드가 올바르지 않거나 이미 사용됐어요.")
        case .notAllowed: String(localized: "이 유형으로는 가입할 수 없어요.")
        case .pendingApproval: String(localized: "서비스 운영자의 승인을 기다리고 있어요. 승인되면 로그인할 수 있어요.")
        case .accountRejected: String(localized: "가입이 반려됐어요. 자세한 내용은 운영자에게 문의해 주세요.")
        case .accountResigned: String(localized: "더 이상 이용할 수 없는 계정이에요.")
        case .accountSuspended: String(localized: "운영규칙 경고가 3회 쌓여 이용이 중단됐어요. 원장님께 문의해 주세요.")
        }
    }

    /// 이 상태의 계정이 쓸 수 없는 이유 (이용 중이면 nil)
    static func blocking(_ status: AccountStatus) -> LoginError? {
        switch status {
        case .active: nil
        case .pending: .pendingApproval
        case .rejected: .accountRejected
        case .resigned: .accountResigned
        case .suspended: .accountSuspended
        }
    }
}

/// 로그인/가입/로그아웃을 담당하는 약속.
/// 서버(Firebase 등)를 붙일 때는 이 약속을 따르는 새 클래스를 만들어 바꿔 끼우면 됩니다.
protocol AuthService {
    func login(id: String, password: String) async throws -> User
    /// 회원가입. 계정만 만들고, 로그인은 따로 합니다.
    /// - 원장: '승인 대기'로 만들어지고, 운영자가 승인해야 로그인할 수 있어요.
    /// - 선생님: 원장이 준 초대 코드가 있어야 가입할 수 있어요.
    /// - 보호자: 바로 가입돼요.
    func register(name: String, id: String, password: String, role: Role, inviteCode: String) async throws -> User
    func logout()
    /// 지금 계정 상태. 로그인 중에도 퇴사·이용 중단이 되면 바로 알아채는 데 씁니다.
    func accountStatus(of userID: String) -> AccountStatus?
}

/// 연습용 가짜 로그인·계정 관리. 가입한 아이디와 비밀번호가 맞아야 들어갑니다.
/// 샘플 계정(owner, teacher, parent, parent2, admin)의 비밀번호는 모두 1234예요.
/// 앱을 끄면 가입 내용이 사라지고, 비밀번호도 앱이 그대로 들고 있는 연습용이에요.
/// (진짜 서버에서는 비밀번호를 앱이 직접 저장하지 않고 서버가 안전하게 보관합니다.)
final class FakeAuthService: AuthService, AccountService {
    /// 로그인과 계정 관리가 같은 데이터를 보도록 하나만 만들어 함께 씁니다.
    static let shared = FakeAuthService()

    private struct Account {
        var password: String
        var user: User
    }

    private var accounts: [String: Account] = [
        "owner": Account(password: "1234", user: SampleData.owner),
        "teacher": Account(password: "1234", user: SampleData.teacher),
        "parent": Account(password: "1234", user: SampleData.parent),
        "parent2": Account(password: "1234", user: SampleData.otherParent),
        "admin": Account(password: "1234", user: SampleData.admin),
        // 운영자 승인 화면을 시험해 볼 수 있는 승인 대기 원장
        "newowner": Account(password: "1234",
                            user: User(id: "user-newowner", name: "새원장", role: .owner,
                                       status: .pending, kindergartenID: "kg-new"))
    ]

    /// 시험용 초대 코드 (DOG123)
    private var inviteList: [StaffInvite] = [
        StaffInvite(id: "invite-sample", code: "DOG123", kindergartenID: "kg-sample",
                    createdByID: SampleData.owner.id, createdAt: .now, usedByID: nil)
    ]

    private func clean(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: 로그인·가입

    func login(id: String, password: String) async throws -> User {
        let cleanID = clean(id)
        guard !cleanID.isEmpty, !password.isEmpty else { throw LoginError.emptyField }

        // 서버에 물어보는 것처럼 잠깐 기다립니다.
        try? await Task.sleep(for: .milliseconds(300))

        guard let account = accounts[cleanID], account.password == password else {
            throw LoginError.invalidCredentials
        }
        // 이용 중인 계정만 들어갈 수 있어요. (퇴사·이용 중단 계정은 여기서 막힙니다)
        if let error = LoginError.blocking(account.user.status) { throw error }
        return account.user
    }

    func register(name: String, id: String, password: String, role: Role, inviteCode: String) async throws -> User {
        let cleanID = clean(id)
        guard !cleanID.isEmpty, !password.isEmpty else { throw LoginError.emptyField }
        guard password.count >= 4 else { throw LoginError.shortPassword }

        try? await Task.sleep(for: .milliseconds(300))

        guard accounts[cleanID] == nil else { throw LoginError.duplicateID }

        var status = AccountStatus.active
        var kindergartenID: String?
        var usedInviteIndex: Int?

        switch role {
        case .owner:
            status = .pending
            kindergartenID = "kg-" + UUID().uuidString
        case .teacher:
            let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard let index = inviteList.firstIndex(where: { $0.code == code && !$0.isUsed }) else {
                throw LoginError.invalidInvite
            }
            kindergartenID = inviteList[index].kindergartenID
            usedInviteIndex = index
        case .parent:
            break
        case .admin:
            throw LoginError.notAllowed
        }

        let user = User(id: "user-" + UUID().uuidString,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        role: role, status: status, kindergartenID: kindergartenID)
        accounts[cleanID] = Account(password: password, user: user)
        if let usedInviteIndex {
            inviteList[usedInviteIndex].usedByID = user.id   // 한 번 쓰면 다시 못 써요
        }
        return user
    }

    func logout() {}

    func accountStatus(of userID: String) -> AccountStatus? {
        accounts.values.first { $0.user.id == userID }?.user.status
    }

    // MARK: 계정 관리

    private func allUsers() -> [User] { accounts.values.map(\.user) }

    private func setStatus(of userID: String, to status: AccountStatus, onlyIf role: Role, from current: AccountStatus?) {
        for key in accounts.keys {
            guard var account = accounts[key], account.user.id == userID,
                  account.user.role == role,
                  current == nil || account.user.status == current else { continue }
            account.user.status = status
            accounts[key] = account
        }
    }

    func owners() -> [User] {
        allUsers().filter { $0.role == .owner }
    }

    func approveOwner(id: String) {
        setStatus(of: id, to: .active, onlyIf: .owner, from: .pending)
    }

    func rejectOwner(id: String) {
        setStatus(of: id, to: .rejected, onlyIf: .owner, from: .pending)
    }

    func staff(inKindergarten kindergartenID: String) -> [User] {
        allUsers().filter { $0.role == .teacher && $0.kindergartenID == kindergartenID }
    }

    func resign(userID: String) {
        setStatus(of: userID, to: .resigned, onlyIf: .teacher, from: .active)
    }

    func invites(inKindergarten kindergartenID: String) -> [StaffInvite] {
        inviteList
            .filter { $0.kindergartenID == kindergartenID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: 운영규칙 경고 (원장이 직접 기록)

    private func updateUser(_ userID: String, _ change: (inout User) -> Void) {
        for key in accounts.keys {
            guard var account = accounts[key], account.user.id == userID else { continue }
            change(&account.user)
            accounts[key] = account
        }
    }

    func parents() -> [User] {
        allUsers().filter { $0.role == .parent }
    }

    func addWarning(userID: String) {
        updateUser(userID) { user in
            guard user.role == .parent, user.status == .active else { return }
            user.warningCount += 1
            if user.warningCount >= KindergartenPolicy.warningLimit {
                user.status = .suspended    // 경고 3회가 되면 바로 이용 중단
            }
        }
    }

    func removeWarning(userID: String) {
        updateUser(userID) { user in
            guard user.role == .parent, user.warningCount > 0 else { return }
            user.warningCount -= 1
            if user.status == .suspended && user.warningCount < KindergartenPolicy.warningLimit {
                user.status = .active       // 경고를 정정해 3회 미만이 되면 이용 재개
            }
        }
    }

    func createInvite(kindergartenID: String, createdBy: String) -> StaffInvite {
        // 헷갈리기 쉬운 글자(0, O, 1, I)는 뺍니다.
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var code = ""
        repeat {
            code = String((0..<6).map { _ in letters.randomElement() ?? "A" })
        } while inviteList.contains { $0.code == code }
        let invite = StaffInvite(id: UUID().uuidString, code: code, kindergartenID: kindergartenID,
                                 createdByID: createdBy, createdAt: .now, usedByID: nil)
        inviteList.append(invite)
        return invite
    }
}
