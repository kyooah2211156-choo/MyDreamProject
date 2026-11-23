import Foundation

/// 사진글(알림장)의 분류. 사진첩에서 이 분류로 걸러 봅니다.
enum PostCategory: String, Codable, CaseIterable, Hashable {
    case program    // 프로그램
    case freeTime   // 자유시간
    case video      // 영상

    var displayName: String {
        switch self {
        case .program: "프로그램"
        case .freeTime: "자유시간"
        case .video: "영상"
        }
    }
}
