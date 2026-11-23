import SwiftUI

/// 공지 상세 (원장만 수정·삭제 가능)
struct NoticeDetailView: View {
    let noticeID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var showingEditor = false
    @State private var confirmingDelete = false

    var body: some View {
        if let user = session.currentUser, let notice = store.notice(id: noticeID) {
            detail(notice, user: user)
        }
    }

    private func detail(_ notice: Notice, user: User) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(notice.title)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.text)
                Text("\(store.authorName(notice.authorID)) · \(notice.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                Text(notice.content)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.text)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.screen)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("공지")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if Permissions.canEdit(notice, by: user) {
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
        .sheet(isPresented: $showingEditor) { NoticeEditorView(mode: .edit(notice)) }
        .confirmationDialog("이 공지를 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                store.deleteNotice(id: notice.id)
                dismiss()
            }
        }
    }
}

#Preview("원장") {
    NavigationStack { NoticeDetailView(noticeID: "notice-1") }
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
}

#Preview("보호자 (수정 불가)") {
    NavigationStack { NoticeDetailView(noticeID: "notice-1") }
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
}
