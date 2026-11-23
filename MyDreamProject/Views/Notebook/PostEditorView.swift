import SwiftUI
import PhotosUI

enum PostEditorMode {
    case create
    case edit(Post)
}

/// 사진글 작성·수정 화면 (원장·선생님). 사진은 최대 10장까지 고를 수 있어요.
struct PostEditorView: View {
    let mode: PostEditorMode
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store

    @State private var text: String
    @State private var photos: [PostPhoto]
    @State private var taggedIDs: Set<String>
    @State private var category: PostCategory
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var errorMessage: String?

    private static let maxPhotos = 10

    init(mode: PostEditorMode) {
        self.mode = mode
        if case .edit(let post) = mode {
            _text = State(initialValue: post.text)
            _photos = State(initialValue: post.photos)
            _taggedIDs = State(initialValue: Set(post.taggedPetIDs))
            _category = State(initialValue: post.category)
        } else {
            _text = State(initialValue: "")
            _photos = State(initialValue: [])
            _taggedIDs = State(initialValue: [])
            _category = State(initialValue: .program)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// 영상 분류면 영상을, 아니면 사진을 고릅니다.
    private var mediaName: String { category == .video ? String(localized: "영상") : String(localized: "사진") }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !isLoadingPhotos && !(photos.isEmpty && trimmedText.isEmpty) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    sectionTitle("분류")
                    Picker("분류", selection: $category) {
                        ForEach(PostCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isEditing)

                    sectionTitle("\(mediaName) \(photos.count)/\(Self.maxPhotos)")
                    photoStrip

                    sectionTitle("내용")
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(AppTheme.text)

                    sectionTitle("함께한 반려견")
                    PetTagPicker(pets: taggablePets, selection: $taggedIDs)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.statusRejected)
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? String(localized: "사진글 수정") : String(localized: "사진글 작성"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(!canSave)
                }
            }
            .onChange(of: category) { _, _ in
                // 분류를 바꾸면 사진/영상 종류가 달라지므로 고른 것을 비웁니다. (새 글 쓸 때만)
                if !isEditing { photos = [] }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPicked(items) }
            }
        }
    }

    /// 태그할 수 있는 반려견 = 승인된 반려견만
    private var taggablePets: [Pet] {
        guard let user = session.currentUser else { return [] }
        return store.visiblePets(for: user)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.text)
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if photos.count < Self.maxPhotos {
                    PhotosPicker(selection: $pickerItems,
                                 maxSelectionCount: Self.maxPhotos - photos.count,
                                 matching: category == .video ? PHPickerFilter.videos : PHPickerFilter.images) {
                        VStack(spacing: 6) {
                            if isLoadingPhotos {
                                ProgressView()
                            } else {
                                Image(systemName: "photo.badge.plus").font(.title2)
                                Text("\(mediaName) 추가").font(AppTheme.Typography.caption)
                            }
                        }
                        .foregroundStyle(AppTheme.softButtonText)
                        .frame(width: 96, height: 96)
                        .background(AppTheme.softButton, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                ForEach(photos) { photo in
                    PhotoImageView(source: photo.source)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                photos.removeAll { $0.id == photo.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("사진 빼기")
                        }
                }
            }
        }
    }

    private func loadPicked(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }
        for item in items {
            guard photos.count < Self.maxPhotos else { break }
            if category == .video {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    photos.append(PostPhoto(id: UUID().uuidString, source: .video(movie.url)))
                }
            } else if let data = try? await item.loadTransferable(type: Data.self) {
                photos.append(PostPhoto(id: UUID().uuidString,
                                        source: .data(PhotoRenderer.compressed(data))))
            }
        }
        pickerItems = []
    }

    private func save() {
        guard let user = session.currentUser else { return }
        let tagIDs = taggablePets.map(\.id).filter { taggedIDs.contains($0) }
        switch mode {
        case .create:
            guard Permissions.canWritePost(user) else {
                errorMessage = String(localized: "사진글을 올릴 권한이 없어요.")
                return
            }
            store.save(post: Post(id: UUID().uuidString, authorID: user.id, text: trimmedText,
                                  photos: photos, taggedPetIDs: tagIDs, date: .now,
                                  category: category))
        case .edit(let original):
            guard Permissions.canEdit(original, by: user) else {
                errorMessage = String(localized: "이 글을 수정할 권한이 없어요.")
                return
            }
            var post = original
            post.text = trimmedText
            post.photos = photos
            post.taggedPetIDs = tagIDs
            store.save(post: post)
        }
        dismiss()
    }
}

#Preview("사진글 작성") {
    PostEditorView(mode: .create)
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
}

#Preview("사진글 수정 (다크)") {
    PostEditorView(mode: .edit(SampleData.posts[0]))
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
