import Foundation

/// 알림장 목록의 한 줄: 공지 또는 사진글
enum FeedItem: Identifiable, Hashable {
    case notice(Notice)
    case post(Post)

    var id: String {
        switch self {
        case .notice(let notice): "notice-" + notice.id
        case .post(let post): "post-" + post.id
        }
    }

    var date: Date {
        switch self {
        case .notice(let notice): notice.date
        case .post(let post): post.date
        }
    }
}

/// 같은 날짜끼리 묶은 알림장 목록
struct FeedDay: Identifiable {
    let day: Date
    let items: [FeedItem]
    var id: Date { day }
}

/// 사진첩에 보이는 사진 한 장 (어느 글에 속한 사진인지 함께 기억)
struct AlbumPhoto: Identifiable, Hashable {
    let photo: PostPhoto
    let postID: String
    var id: String { photo.id }
}

/// 사진첩에서 강아지별·날짜별로 좁혀 볼 때 쓰는 조건 (둘 다 비어 있으면 전체)
struct AlbumFilter: Hashable {
    var petID: String? = nil
    var day: Date? = nil
}
