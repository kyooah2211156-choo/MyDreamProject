import Foundation

/// 개인정보 수집·이용 안내 문구 (초안).
/// 실제 서비스 전에 유치원 사정에 맞게 고치고, 법적 검토를 받아야 해요.
/// 문구를 바꾸고 싶으면 이 파일만 고치면 됩니다.
enum PrivacyConsent {
    struct Section: Identifiable {
        let title: String
        let lines: [String]
        var id: String { title }
    }

    static let title = String(localized: "개인정보 수집·이용 안내")

    static let sections: [Section] = [
        Section(title: String(localized: "수집·이용 목적"), lines: [
            String(localized: "보호자 확인과 가입 승인"),
            String(localized: "반려견 돌봄·교육·안전 관리"),
            String(localized: "알림장, 사진, 공지 등 서비스 제공"),
            String(localized: "운영규칙 안내와 이용 관리")
        ]),
        Section(title: String(localized: "수집하는 항목"), lines: [
            String(localized: "보호자: 이름, 아이디, 비밀번호"),
            String(localized: "반려견: 이름, 견종, 성별, 연령(생년월일), 중성화 여부, 예방접종, 알러지, 건강상태, 성향, 동물등록 여부"),
            String(localized: "이용 중 올리는 내용: 사진, 영상, 댓글")
        ]),
        Section(title: String(localized: "보유·이용 기간"), lines: [
            String(localized: "회원 탈퇴 시까지 보관하고 이후 지워요. 법령에서 따로 보관하라고 정한 경우에는 그 기간 동안 보관해요.")
        ]),
        Section(title: String(localized: "동의를 거부할 권리"), lines: [
            String(localized: "동의를 거부할 수 있어요. 다만 거부하면 보호자 가입과 서비스 이용이 어려워요.")
        ])
    ]
}
