import Foundation
import Observation

/// 원장 승인, 선생님 초대, 직원 퇴사 처리를 맡는 데이터 창고
@Observable
final class AccountStore {
    private let service: AccountService
    private(set) var owners: [User] = []
    private(set) var staff: [User] = []
    private(set) var invites: [StaffInvite] = []
    private(set) var parents: [User] = []

    init(service: AccountService = FakeAuthService.shared) {
        self.service = service
        reloadOwners()
    }

    // MARK: 서비스 운영자

    func reloadOwners() {
        // 승인 대기가 위로 오게 정렬
        owners = service.owners().sorted {
            ($0.status == .pending ? 0 : 1, $0.name) < ($1.status == .pending ? 0 : 1, $1.name)
        }
    }

    func approveOwner(id: String) {
        service.approveOwner(id: id)
        reloadOwners()
    }

    func rejectOwner(id: String) {
        service.rejectOwner(id: id)
        reloadOwners()
    }

    var pendingOwnerCount: Int { owners.filter { $0.status == .pending }.count }

    // MARK: 원장

    /// 우리 유치원의 직원과 초대 코드를 새로 불러옵니다.
    func reloadStaff(kindergartenID: String) {
        staff = service.staff(inKindergarten: kindergartenID).sorted { $0.name < $1.name }
        invites = service.invites(inKindergarten: kindergartenID)
    }

    func createInvite(kindergartenID: String, createdBy: String) {
        _ = service.createInvite(kindergartenID: kindergartenID, createdBy: createdBy)
        reloadStaff(kindergartenID: kindergartenID)
    }

    // MARK: 보호자 경고

    func reloadParents() {
        parents = service.parents().sorted { $0.name < $1.name }
    }

    func addWarning(userID: String) {
        service.addWarning(userID: userID)
        reloadParents()
    }

    func removeWarning(userID: String) {
        service.removeWarning(userID: userID)
        reloadParents()
    }

    func parent(id: String) -> User? { parents.first { $0.id == id } }

    func resign(userID: String, kindergartenID: String) {
        service.resign(userID: userID)
        reloadStaff(kindergartenID: kindergartenID)
    }
}
