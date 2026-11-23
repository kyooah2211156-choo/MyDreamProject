import Foundation

/// 원장이 쓰는 공지
struct Notice: Identifiable, Codable, Hashable {
    let id: String
    var authorID: String
    var title: String
    var content: String
    var date: Date
}
