import Foundation

/// 알림장의 사진글 (반려견 사진 + 글). 사진첩은 이 사진들을 모아서 보여줍니다.
struct Post: Identifiable, Codable, Hashable {
    let id: String
    var authorID: String
    var text: String
    var photos: [PostPhoto]
    var taggedPetIDs: [String]
    var date: Date
    var category: PostCategory = .freeTime   // 프로그램 / 자유시간 / 영상
    var isPublished: Bool = true            // false면 임시저장 (작성한 직원과 원장만 보이고, 사진첩에도 안 나와요)
}
