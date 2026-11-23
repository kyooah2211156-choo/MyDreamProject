import SwiftUI

enum NoticeEditorMode {
    case create
    case edit(Notice)
}

/// 공지 작성·수정 화면 (원장 전용)
struct NoticeEditorView: View {
    let mode: NoticeEditorMode
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var title: String
    @State private var content: String

    init(mode: NoticeEditorMode) {
        self.mode = mode
        if case .edit(let notice) = mode {
            _title = State(initialValue: notice.title)
            _content = State(initialValue: notice.content)
        } else {
            _title = State(initialValue: "")
            _content = State(initialValue: "")
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    TextField("제목", text: $title)
                        .font(AppTheme.Typography.headline)
                        .padding(14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                    TextEditor(text: $content)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                        .padding(10)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                }
                .foregroundStyle(AppTheme.text)
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? String(localized: "공지 수정") : String(localized: "공지 작성"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let user = session.currentUser, Permissions.canWriteNotice(user) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .create:
            store.save(notice: Notice(id: UUID().uuidString, authorID: user.id,
                                      title: cleanTitle, content: cleanContent, date: .now))
        case .edit(let original):
            var notice = original
            notice.title = cleanTitle
            notice.content = cleanContent
            store.save(notice: notice)
        }
        dismiss()
    }
}

#Preview("공지 작성") {
    NoticeEditorView(mode: .create)
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
}

#Preview("공지 수정 (다크)") {
    NoticeEditorView(mode: .edit(SampleData.notices[0]))
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
