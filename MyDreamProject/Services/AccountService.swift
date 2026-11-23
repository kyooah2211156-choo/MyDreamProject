import Foundation

/// 계정 관리(원장 승인, 선생님 초대, 직원 퇴사)를 담당하는 약속.
/// 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
/// 진짜 서비스에서는 권한 확인과 초대 코드 검사를 서버가 해야 안전해요.
protocol AccountService {
    // 서비스 운영자
    func owners() -> [User]
    func approveOwner(id: String)
    func rejectOwner(id: String)

    // 원장
    func staff(inKindergarten kindergartenID: String) -> [User]
    func resign(userID: String)
    func invites(inKindergarten kindergartenID: String) -> [StaffInvite]
    func createInvite(kindergartenID: String, createdBy: String) -> StaffInvite

    // 원장: 보호자 운영규칙 경고 (3회가 되면 이용 중단)
    func parents() -> [User]
    func addWarning(userID: String)
    func removeWarning(userID: String)
}
