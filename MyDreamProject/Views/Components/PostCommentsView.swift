import SwiftUI

/// 사진글의 댓글을 보고 쓰는 창. 사진첩에서 사진을 크게 볼 때 아래에서 올라옵니다.
struct PostCommentsView: View {
    let postID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var text = ""

    var body: some View {
        NavigationStack {
            if let user = session.currentUser {
                content(user)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func content(_ user: User) -> some View {
        let comments = store.comments(for: postID)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if comments.isEmpty {
                    Text("첫 댓글을 남겨 보세요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.authorName(comment.authorID))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.softButtonText)
                        Text(comment.content)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.text)
                        Text(comment.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("댓글 \(comments.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
        }
        .safeAreaInset(edge: .bottom) { inputBar(user) }
    }

    private func inputBar(_ user: User) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 8) {
            TextField("댓글을 입력하세요", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .padding(12)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
            Button {
                store.addComment(postID: postID, authorID: user.id, content: trimmed)
                text = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(trimmed.isEmpty ? AppTheme.subText : AppTheme.softButtonText)
            }
            .disabled(trimmed.isEmpty || !Permissions.canComment(user))
            .accessibilityLabel("댓글 보내기")
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview("보호자") {
    PostCommentsView(postID: "post-1")
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
}

#Preview("선생님 (다크)") {
    PostCommentsView(postID: "post-1")
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
