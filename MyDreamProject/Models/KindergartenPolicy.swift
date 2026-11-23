import Foundation

/// 유치원 철학과 운영규칙 문구. 문구를 바꾸고 싶으면 이 파일만 고치면 됩니다.
enum KindergartenPolicy {
    static let philosophyTitle = "우리 유치원의 철학"
    static let philosophy: [String] = [
        "내 강아지가 소중한 만큼 다른 생명도 소중합니다.",
        "사랑에는 책임이 따르고, 배려에서 올바른 반려문화가 시작됩니다."
    ]

    static let rulesTitle = "운영규칙"
    static let rulesIntro = "함께 지켜 주세요"
    static let ruleItems: [String] = [
        "교육에 협조",
        "안전수칙",
        "다른 보호자 & 강아지들에게 피해"
    ]
    /// 경고 3회 시 이용 중단
    static let warningLimit = 3
    static let rulesNotice = "위 내용을 반복적으로 위반하는 경우 경고 \(warningLimit)회 시 이용을 중단합니다."
}
