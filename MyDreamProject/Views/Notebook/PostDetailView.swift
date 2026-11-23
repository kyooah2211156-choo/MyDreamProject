import SwiftUI

/// 사진글 상세: 사진 넘겨 보기, 댓글, (권한이 있으면) 수정·삭제
struct PostDetailView: View {
    let postID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var commentText = ""
    @State private var showingEditor = false
    @State private var confirmingDelete = false

    var body: some View {
        if let user = session.currentUser, let post = store.post(id: postID) {
            detail(post, user: user)
        }
    }

    private func detail(_ post: Post, user: User) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                if !post.photos.isEmpty { photoPager(post) }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(store.authorName(post.authorID)) · \(post.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                    if !post.text.isEmpty {
                        Text(post.text)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.text)
                    }
                    PetNameTags(names: store.petNames(for: post))
                }
                .padding(.horizontal, AppTheme.Spacing.large)

                commentsSection(post)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("사진글")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if Permissions.canEdit(post, by: user) {
                    Menu {
                        Button("수정", systemImage: "pencil") { showingEditor = true }
                        Button("삭제", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("수정 또는 삭제")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { commentBar(post, user: user) }
        .sheet(isPresented: $showingEditor) { PostEditorView(mode: .edit(post)) }
        .confirmationDialog("이 사진글을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                store.deletePost(id: post.id)
                dismiss()
            }
        } message: {
            Text("사진과 댓글이 모두 사라져요.")
        }
    }

    /// 사진이 여러 장이면 좌우로 넘기고, 아래에 점(페이지 표시)이 나옵니다.
    private func photoPager(_ post: Post) -> some View {
        TabView {
            ForEach(post.photos) { photo in
                MediaPageView(source: photo.source)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: post.photos.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 340)
    }

    private func commentsSection(_ post: Post) -> some View {
        let comments = store.comments(for: post.id)
        return VStack(alignment: .leading, spacing: 10) {
            Text("댓글 \(comments.count)")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            if comments.isEmpty {
                Text("첫 댓글을 남겨 보세요")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
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
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.bottom, AppTheme.Spacing.large)
    }

    private func commentBar(_ post: Post, user: User) -> some View {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 8) {
            TextField("댓글을 입력하세요", text: $commentText, axis: .vertical)
                .lineLimit(1...3)
                .padding(12)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
            Button {
                store.addComment(postID: post.id, authorID: user.id, content: trimmed)
                commentText = ""
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

#Preview("선생님 (본인 글)") {
    NavigationStack { PostDetailView(postID: "post-1") }
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
}

#Preview("보호자 (수정 불가)") {
    NavigationStack { PostDetailView(postID: "post-1") }
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
