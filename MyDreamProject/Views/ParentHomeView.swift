import SwiftUI

/// 보호자 홈: 내 반려견을 가로로 넘겨 보고, 고른 반려견 기준으로 사진과 알림장을 보여줍니다.
struct ParentHomeView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var selectedPetID: String?
    @State private var showingPolicy = false

    private let kindergartenName = UserDefaultsKindergartenNameStore().load() ?? "댕댕이 유치원"

    var body: some View {
        NavigationStack {
            if let user = session.currentUser {
                content(for: user)
            }
        }
    }

    private func content(for user: User) -> some View {
        // 내 반려견은 승인 상태와 관계없이 모두 보입니다. (대기중·반려됨 포함)
        let pets = store.pets.filter { $0.ownerID == user.id }
        let selected = pets.first { $0.id == selectedPetID }
            ?? pets.first { $0.isApproved }
            ?? pets.first
        return ScrollView {
            VStack(spacing: 0) {
                hero(user)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Button {
                        showingPolicy = true
                    } label: {
                        Label("운영규칙 · 개인정보 보기", systemImage: "checkmark.shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle())

                    sectionTitle("내 반려견")
                    if pets.isEmpty {
                        infoCard(icon: "pawprint", title: String(localized: "등록된 반려견이 없어요"),
                                 message: String(localized: "반려견 등록 신청은 다음 단계에서 만들어요."), color: AppTheme.subText)
                    } else {
                        petCarousel(pets, selected: selected)
                    }
                    if let selected {
                        detail(for: selected, user: user)
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingPolicy) { PolicySheetView() }
    }

    // MARK: 머리말

    private func hero(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("안녕하세요, \(user.name)님 🐾")
                .font(AppTheme.Typography.caption)
                .opacity(0.9)
            Text(kindergartenName)
                .font(AppTheme.Typography.largeTitle)
                .lineLimit(2)
            Text("댕답개 배우개")
                .font(AppTheme.Typography.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.28), in: Capsule())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.screen)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: AppTheme.Radius.hero,
                                   bottomTrailingRadius: AppTheme.Radius.hero)
                .fill(AppTheme.hero)
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: 반려견 가로 목록

    private func petCarousel(_ pets: [Pet], selected: Pet?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.medium) {
                ForEach(pets) { pet in
                    petCard(pet, isSelected: pet.id == selected?.id)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
    }

    private func petCard(_ pet: Pet, isSelected: Bool) -> some View {
        Button {
            selectedPetID = pet.id
        } label: {
            VStack(spacing: 6) {
                avatar(pet)
                Text(pet.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Text(pet.breed)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                PetStatusBadge(status: pet.status)
            }
            .frame(width: 124)
            .padding(.vertical, 14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                    .stroke(isSelected ? AppTheme.buttonShadow : Color.clear, lineWidth: 3)
            }
            .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pet.name), \(pet.status.displayName)")
    }

    private func avatar(_ pet: Pet) -> some View {
        Group {
            if let photo = pet.profilePhoto {
                PhotoImageView(source: photo)
            } else {
                AppTheme.avatar.overlay {
                    Image(systemName: "dog.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.softButtonText)
                }
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
    }

    // MARK: 고른 반려견 내용

    @ViewBuilder
    private func detail(for pet: Pet, user: User) -> some View {
        PetProfileCard(pet: pet)
        switch pet.status {
        case .approved:
            approvedContent(pet, user: user)
        case .pending:
            infoCard(icon: "hourglass", title: String(localized: "승인을 기다리는 중이에요"),
                     message: String(localized: "원장님이나 선생님이 확인하면 \(pet.name)의 알림장과 사진을 볼 수 있어요."),
                     color: AppTheme.statusPending)
        case .rejected:
            infoCard(icon: "exclamationmark.triangle.fill", title: String(localized: "등록이 반려됐어요"),
                     message: pet.rejectionReason ?? String(localized: "반려 사유가 적혀 있지 않아요."),
                     color: AppTheme.statusRejected)
        }
    }

    private func approvedContent(_ pet: Pet, user: User) -> some View {
        let posts = store.visiblePosts(for: user).filter { $0.taggedPetIDs.contains(pet.id) }
        let photos = posts.flatMap { post in
            post.photos.map { AlbumPhoto(photo: $0, postID: post.id) }
        }
        let notices = store.notices.sorted { $0.date > $1.date }.prefix(2)

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            HealthRecordsCard(petIDs: [pet.id], canEdit: false)

            sectionTitle("\(pet.name)의 최근 사진")
            if photos.isEmpty {
                emptyText("아직 올라온 사진이 없어요")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos.prefix(8)) { item in
                            NavigationLink {
                                PostDetailView(postID: item.postID)
                            } label: {
                                PhotoImageView(source: item.photo.source)
                                    .frame(width: 112, height: 112)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .accessibilityLabel("사진 보기")
                        }
                    }
                }
            }

            sectionTitle("\(pet.name)의 알림장")
            if posts.isEmpty {
                emptyText("아직 알림장이 없어요")
            } else {
                ForEach(posts.prefix(3)) { post in
                    NavigationLink {
                        PostDetailView(postID: post.id)
                    } label: {
                        postCard(post)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !notices.isEmpty {
                sectionTitle("공지")
                ForEach(Array(notices)) { notice in
                    NavigationLink {
                        NoticeDetailView(noticeID: notice.id)
                    } label: {
                        noticeCard(notice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func postCard(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.text)
                .lineLimit(2)
            Text("\(store.authorName(post.authorID)) · \(post.date.formatted(date: .abbreviated, time: .shortened))")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    private func noticeCard(_ notice: Notice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(notice.title, systemImage: "megaphone.fill")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            Text(notice.content)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    // MARK: 작은 조각들

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.text)
    }

    private func emptyText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.subText)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    private func infoCard(icon: String, title: String, message: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title).foregroundStyle(color)
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.subText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}

/// 반려견 등록 상태 배지 (대기중 / 승인됨 / 반려됨)
struct PetStatusBadge: View {
    let status: PetStatus

    private var color: Color {
        switch status {
        case .pending: AppTheme.statusPending
        case .approved: AppTheme.statusApproved
        case .rejected: AppTheme.statusRejected
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

#Preview("보호자 (라이트)") {
    ParentHomeView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(AccountStore())
        .environment(HealthRecordStore())
}

#Preview("보호자 (다크)") {
    ParentHomeView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(AccountStore())
        .environment(HealthRecordStore())
        .preferredColorScheme(.dark)
}

#Preview("반려견이 없는 보호자") {
    ParentHomeView()
        .environment(SessionStore(currentUser: User(id: "user-new", name: "새보호", role: .parent)))
        .environment(NotebookStore())
        .environment(AccountStore())
        .environment(HealthRecordStore())
}
