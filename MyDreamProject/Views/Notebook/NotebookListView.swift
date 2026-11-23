import SwiftUI

/// 알림장 목록: 날짜별로 묶어서 공지와 사진글을 구분해 보여줍니다.
struct NotebookListView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var showingPostEditor = false
    @State private var showingNoticeEditor = false

    var body: some View {
        NavigationStack {
            if let user = session.currentUser {
                content(for: user)
            }
        }
    }

    private func content(for user: User) -> some View {
        let days = store.feed(for: user)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                if days.isEmpty {
                    Text("아직 알림장이 없어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
                ForEach(days) { day in
                    Text(day.day.formatted(.dateTime.month().day().weekday(.abbreviated)))
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.subText)
                        .padding(.top, 8)
                    ForEach(day.items) { item in
                        row(item)
                    }
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("알림장")
        .toolbar {
            // 작성 버튼은 권한이 있는 사람에게만 보입니다. (보호자는 버튼 없음)
            ToolbarItem(placement: .topBarTrailing) {
                if Permissions.canWritePost(user) {
                    Menu {
                        if Permissions.canWriteNotice(user) {
                            Button("공지 작성", systemImage: "megaphone") { showingNoticeEditor = true }
                        }
                        Button("사진글 작성", systemImage: "camera") { showingPostEditor = true }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("알림장 작성")
                }
            }
        }
        .sheet(isPresented: $showingPostEditor) { PostEditorView(mode: .create) }
        .sheet(isPresented: $showingNoticeEditor) { NoticeEditorView(mode: .create) }
    }

    @ViewBuilder
    private func row(_ item: FeedItem) -> some View {
        switch item {
        case .notice(let notice):
            NavigationLink {
                NoticeDetailView(noticeID: notice.id)
            } label: {
                NoticeRow(notice: notice)
            }
            .buttonStyle(.plain)
        case .post(let post):
            NavigationLink {
                PostDetailView(postID: post.id)
            } label: {
                PostRow(post: post)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FeedBadge: View {
    let title: LocalizedStringKey
    let color: Color

    var body: some View {
        Text(title)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

private struct NoticeRow: View {
    let notice: Notice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FeedBadge(title: "공지", color: AppTheme.statusPending)
            Text(notice.title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            Text(notice.content)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.subText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }
}

private struct PostRow: View {
    let post: Post
    @Environment(NotebookStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let first = post.photos.first {
                PhotoImageView(source: first.source)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomTrailing) {
                        if post.photos.count > 1 {
                            Label("\(post.photos.count)", systemImage: "photo.on.rectangle")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.black.opacity(0.5), in: Capsule())
                                .padding(4)
                        }
                    }
            }
            VStack(alignment: .leading, spacing: 6) {
                FeedBadge(title: "사진글", color: AppTheme.statusApproved)
                Text(post.text)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
                Text("\(store.authorName(post.authorID)) · \(post.date.formatted(date: .omitted, time: .shortened))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }
}

#Preview("원장") {
    NotebookListView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
}

#Preview("보호자 (작성 버튼 없음)") {
    NotebookListView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
}

#Preview("선생님 (다크)") {
    NotebookListView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
