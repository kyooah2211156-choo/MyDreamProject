import Foundation

/// 알림장·사진글·댓글 데이터를 읽고 쓰는 약속.
/// 서버(Firebase 등)를 붙일 때는 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol NotebookService {
    func loadPosts() -> [Post]
    func loadNotices() -> [Notice]
    func loadComments() -> [Comment]
    func loadPets() -> [Pet]

    /// 같은 id가 있으면 덮어쓰고, 없으면 새로 추가합니다.
    func save(post: Post)
    func deletePost(id: String)
    func save(notice: Notice)
    func deleteNotice(id: String)
    func add(comment: Comment)
    func add(pet: Pet)
    func update(pet: Pet)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소 (샘플 데이터로 시작)
final class FakeNotebookService: NotebookService {
    private var posts = SampleData.posts
    private var notices = SampleData.notices
    private var comments = SampleData.comments
    private var pets = SampleData.pets

    func loadPosts() -> [Post] { posts }
    func loadNotices() -> [Notice] { notices }
    func loadComments() -> [Comment] { comments }
    func loadPets() -> [Pet] { pets }

    func save(post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        } else {
            posts.insert(post, at: 0)
        }
    }

    func deletePost(id: String) {
        posts.removeAll { $0.id == id }
        comments.removeAll { $0.postID == id }
    }

    func save(notice: Notice) {
        if let index = notices.firstIndex(where: { $0.id == notice.id }) {
            notices[index] = notice
        } else {
            notices.insert(notice, at: 0)
        }
    }

    func deleteNotice(id: String) {
        notices.removeAll { $0.id == id }
    }

    func add(comment: Comment) {
        comments.append(comment)
    }

    func add(pet: Pet) {
        pets.append(pet)
    }

    func update(pet: Pet) {
        guard let index = pets.firstIndex(where: { $0.id == pet.id }) else { return }
        pets[index] = pet
    }
}
