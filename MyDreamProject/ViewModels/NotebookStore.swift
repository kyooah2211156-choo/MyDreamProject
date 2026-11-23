import Foundation
import Observation

/// 알림장과 사진첩이 함께 쓰는 데이터 창고.
/// 글이 바뀌면 알림장 목록과 사진첩이 같이 바뀝니다. (사진첩은 별도 저장소 없이 Post의 사진을 모아서 보여줍니다)
@Observable
final class NotebookStore {
    private let service: NotebookService
    private(set) var posts: [Post] = []
    private(set) var notices: [Notice] = []
    private(set) var comments: [Comment] = []
    private(set) var pets: [Pet] = []
    /// 작성자 이름을 찾는 데 쓰는 사용자 목록 (새로 가입한 사람도 여기에 추가)
    private(set) var users: [User] = SampleData.users

    init(service: NotebookService = FakeNotebookService()) {
        self.service = service
        reload()
    }

    private func reload() {
        posts = service.loadPosts()
        notices = service.loadNotices()
        comments = service.loadComments()
        pets = service.loadPets()
    }

    // MARK: 찾기

    func post(id: String) -> Post? { posts.first { $0.id == id } }
    func notice(id: String) -> Notice? { notices.first { $0.id == id } }

    func authorName(_ userID: String) -> String {
        users.first { $0.id == userID }?.name ?? String(localized: "알 수 없음")
    }

    func petNames(for post: Post) -> [String] {
        post.taggedPetIDs.compactMap { id in pets.first { $0.id == id }?.name }
    }

    func comments(for postID: String) -> [Comment] {
        comments.filter { $0.postID == postID }.sorted { $0.date < $1.date }
    }

    // MARK: 권한에 맞게 걸러서 보여주기

    /// 승인된 반려견만. 원장·선생님은 전체, 보호자는 내 반려견만.
    func visiblePets(for user: User) -> [Pet] {
        let approved = pets.filter(\.isApproved)
        switch user.role {
        case .owner, .teacher: return approved
        case .parent: return approved.filter { $0.ownerID == user.id }
        case .admin: return []
        }
    }

    func visiblePosts(for user: User) -> [Post] {
        posts
            .filter { Permissions.canView($0, by: user, pets: pets) }
            .sorted { $0.date > $1.date }
    }

    /// 날짜별로 묶은 알림장 (최신 날짜가 위)
    func feed(for user: User) -> [FeedDay] {
        let items = notices.map(FeedItem.notice) + visiblePosts(for: user).map(FeedItem.post)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            FeedDay(day: day, items: (grouped[day] ?? []).sorted { $0.date > $1.date })
        }
    }

    /// 사진첩에 보일 사진들 (분류: 프로그램 / 자유시간 / 영상, nil이면 전체)
    func albumPhotos(for user: User, category: PostCategory?) -> [AlbumPhoto] {
        visiblePosts(for: user)
            .filter { post in category.map { post.category == $0 } ?? true }
            .flatMap { post in post.photos.map { AlbumPhoto(photo: $0, postID: post.id) } }
    }

    // MARK: 가입

    func register(user: User) {
        guard !users.contains(where: { $0.id == user.id }) else { return }
        users.append(user)
    }

    /// 새 반려견 등록 신청 (처음에는 '대기중')
    func addPet(_ pet: Pet) {
        service.add(pet: pet)
        reload()
    }

    // MARK: 반려견 등록 승인

    /// 반려된 반려견을 고쳐서 다시 신청 ('대기중'으로 돌아가요)
    func resubmitPet(_ pet: Pet) {
        guard let current = pets.first(where: { $0.id == pet.id }), current.status == .rejected else { return }
        var updated = pet
        updated.status = .pending
        updated.rejectionReason = nil
        updated.reviewerID = nil
        service.update(pet: updated)
        reload()
    }

    /// 승인을 기다리는 반려견
    var pendingPets: [Pet] { pets.filter { $0.status == .pending } }

    /// 승인. 바뀐 반려견을 돌려줍니다. (화면에서 권한을 먼저 확인한 뒤 호출)
    @discardableResult
    func approvePet(id: String, reviewerID: String) -> Pet? {
        guard var pet = pets.first(where: { $0.id == id }), pet.status == .pending else { return nil }
        pet.status = .approved
        pet.rejectionReason = nil
        pet.reviewerID = reviewerID
        service.update(pet: pet)
        reload()
        return pet
    }

    /// 반려. 사유는 꼭 필요합니다.
    @discardableResult
    func rejectPet(id: String, reviewerID: String, reason: String) -> Pet? {
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanReason.isEmpty,
              var pet = pets.first(where: { $0.id == id }), pet.status == .pending else { return nil }
        pet.status = .rejected
        pet.rejectionReason = cleanReason
        pet.reviewerID = reviewerID
        service.update(pet: pet)
        reload()
        return pet
    }

    // MARK: 쓰기 (화면에서는 권한을 먼저 확인한 뒤 호출)

    func save(post: Post) {
        service.save(post: post)
        reload()
    }

    func deletePost(id: String) {
        service.deletePost(id: id)
        reload()
    }

    /// 사진 한 장만 지우기 (글과 나머지 사진은 남음)
    func deletePhoto(postID: String, photoID: String) {
        guard var post = post(id: postID) else { return }
        post.photos.removeAll { $0.id == photoID }
        save(post: post)
    }

    func save(notice: Notice) {
        service.save(notice: notice)
        reload()
    }

    func deleteNotice(id: String) {
        service.deleteNotice(id: id)
        reload()
    }

    func addComment(postID: String, authorID: String, content: String) {
        let comment = Comment(id: UUID().uuidString, postID: postID, authorID: authorID,
                              content: content, date: .now)
        service.add(comment: comment)
        reload()
    }
}
