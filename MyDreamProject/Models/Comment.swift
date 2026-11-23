import Foundation

/// 사진글에 달리는 댓글
struct Comment: Identifiable, Codable, Hashable {
    let id: String
    var postID: String
    var authorID: String
    var content: String
    var date: Date
}
