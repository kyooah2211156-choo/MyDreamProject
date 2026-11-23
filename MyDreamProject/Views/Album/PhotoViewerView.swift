import SwiftUI

/// 사진 크게 보기: 좌우로 넘기기, 저장·공유, (권한이 있으면) 설명·태그 수정과 사진 삭제
struct PhotoViewerView: View {
    let category: PostCategory?
    @State private var selection: String
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var confirmingDelete = false
    @State private var editingCaptionPostID: String?
    @State private var resultMessage: String?
    @State private var showingComments = false

    init(startID: String, category: PostCategory?) {
        _selection = State(initialValue: startID)
        self.category = category
    }

    /// 지금 보고 있는 목록 (글이 바뀌면 함께 바뀜)
    private var items: [AlbumPhoto] {
        guard let user = session.currentUser else { return [] }
        return store.albumPhotos(for: user, category: category)
    }

    private var current: AlbumPhoto? { items.first { $0.id == selection } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(items) { item in
                    MediaPageView(source: item.photo.source, contentMode: .fit)
                        .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { caption }
        .confirmationDialog("이 사진·영상을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("사진 삭제", role: .destructive) { deleteCurrent() }
        } message: {
            Text("글과 다른 사진은 그대로 남아요.")
        }
        .sheet(item: Binding(
            get: { editingCaptionPostID.map { CaptionTarget(id: $0) } },
            set: { editingCaptionPostID = $0?.id }
        )) { target in
            PostCaptionEditorView(postID: target.id)
        }
        .alert("사진 저장", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
        .onChange(of: items.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    private struct CaptionTarget: Identifiable { let id: String }

    // MARK: 위쪽 버튼

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .font(.title)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("닫기")
            Spacer()
            if let current {
                Menu {
                    shareButton(current.photo.source)
                    Button("사진 앱에 저장", systemImage: "square.and.arrow.down") {
                        Task { resultMessage = await PhotoSaver.save([current.photo.source]) }
                    }
                    if canEdit(current) {
                        Button("설명·태그 수정", systemImage: "pencil") {
                            editingCaptionPostID = current.postID
                        }
                        Button("삭제", systemImage: "trash", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .font(.title)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("더보기")
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: 아래 설명

    @ViewBuilder
    private var caption: some View {
        if let current, let post = store.post(id: current.postID) {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    if !post.text.isEmpty {
                        Text(post.text)
                            .font(AppTheme.Typography.body)
                            .lineLimit(3)
                    }
                    PetNameTags(names: store.petNames(for: post))
                }
                Spacer(minLength: 0)
                Button {
                    showingComments = true
                } label: {
                    Label("\(store.comments(for: post.id).count)", systemImage: "bubble.left.fill")
                        .font(AppTheme.Typography.headline)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                .accessibilityLabel("댓글 보기")
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.large)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            )
            .sheet(isPresented: $showingComments) {
                PostCommentsView(postID: post.id)
            }
        }
    }

    @ViewBuilder
    private func shareButton(_ source: PhotoSource) -> some View {
        if case .video(let url) = source {
            ShareLink(item: url) {
                Label("공유", systemImage: "square.and.arrow.up")
            }
        } else {
            ShareLink(item: SharablePhoto(source: source),
                      preview: SharePreview(String(localized: "댕답개 배우개 사진"))) {
                Label("공유", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func canEdit(_ item: AlbumPhoto) -> Bool {
        guard let user = session.currentUser, let post = store.post(id: item.postID) else { return false }
        return Permissions.canEdit(post, by: user)
    }

    private func deleteCurrent() {
        guard let item = current, canEdit(item) else { return }
        let oldIndex = items.firstIndex { $0.id == item.id } ?? 0
        store.deletePhoto(postID: item.postID, photoID: item.photo.id)
        let newItems = items
        if !newItems.isEmpty {
            selection = newItems[min(oldIndex, newItems.count - 1)].id
        }
    }
}

/// 사진글의 설명과 태그 반려견만 고치는 작은 화면
struct PostCaptionEditorView: View {
    let postID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var text = ""
    @State private var taggedIDs: Set<String> = []
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Text("설명").font(AppTheme.Typography.headline)
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                    Text("함께한 반려견").font(AppTheme.Typography.headline)
                    PetTagPicker(pets: taggablePets, selection: $taggedIDs)
                }
                .foregroundStyle(AppTheme.text)
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("설명·태그 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장", action: save) }
            }
            .onAppear(perform: load)
        }
    }

    private var taggablePets: [Pet] {
        guard let user = session.currentUser else { return [] }
        return store.visiblePets(for: user)
    }

    private func load() {
        guard !didLoad, let post = store.post(id: postID) else { return }
        didLoad = true
        text = post.text
        taggedIDs = Set(post.taggedPetIDs)
    }

    private func save() {
        guard let user = session.currentUser,
              var post = store.post(id: postID),
              Permissions.canEdit(post, by: user) else { return }
        post.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        post.taggedPetIDs = taggablePets.map(\.id).filter { taggedIDs.contains($0) }
        store.save(post: post)
        dismiss()
    }
}

#Preview("사진 크게 보기 (원장)") {
    PhotoViewerView(startID: "p1-1", category: nil)
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
}

#Preview("사진 크게 보기 (보호자)") {
    PhotoViewerView(startID: "p1-1", category: nil)
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
}

#Preview("설명·태그 수정") {
    PostCaptionEditorView(postID: "post-1")
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
}
