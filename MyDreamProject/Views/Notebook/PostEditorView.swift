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
    @Environment(HealthRecordStore.self) private var health
    /// 오늘 등원 정보 (원장·선생님 화면에서만 있어요)
    @Environment(TeacherHomeViewModel.self) private var attendance: TeacherHomeViewModel?

    @State private var text: String
    @State private var photos: [PostPhoto]
    @State private var selectedPetID: String?
    @State private var healthInput = HealthInputState()
    @State private var didLoadHealth = false
    @State private var category: PostCategory
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var errorMessage: String?

    private static let maxPhotos = 10

    /// 새 글은 반려견 한 마리의 알림장이에요. 홈에서 강아지 카드로 열면 initialTaggedPetIDs에 그 강아지가 들어와서 정해진 채로 열립니다.
    private let fixedPetID: String?
    private let originalTags: [String]

    init(mode: PostEditorMode, initialTaggedPetIDs: Set<String> = []) {
        self.mode = mode
        if case .edit(let post) = mode {
            _text = State(initialValue: post.text)
            _photos = State(initialValue: post.photos)
            _selectedPetID = State(initialValue: post.taggedPetIDs.count == 1 ? post.taggedPetIDs.first : nil)
            _category = State(initialValue: post.category)
            fixedPetID = post.taggedPetIDs.count == 1 ? post.taggedPetIDs.first : nil
            originalTags = post.taggedPetIDs
        } else {
            _text = State(initialValue: "")
            _photos = State(initialValue: [])
            let single = initialTaggedPetIDs.count == 1 ? initialTaggedPetIDs.first : nil
            _selectedPetID = State(initialValue: single)
            _category = State(initialValue: .program)
            fixedPetID = single
            originalTags = []
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// 영상 분류면 영상을, 아니면 사진을 고릅니다.
    private var mediaName: String { category == .video ? String(localized: "영상") : String(localized: "사진") }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// 이 글이 속한 반려견 (새 글은 반드시 정해야 해요. 예전에 여러 마리를 태그한 글은 정하지 않아도 돼요)
    private var petID: String? { fixedPetID ?? selectedPetID }
    private var isLegacyGroupPost: Bool { isEditing && originalTags.count > 1 }
    private var needsPetChoice: Bool { !isEditing && fixedPetID == nil }

    private var canSave: Bool {
        guard !isLoadingPhotos, !(photos.isEmpty && trimmedText.isEmpty) else { return false }
        return isLegacyGroupPost || petID != nil
    }

    /// 글을 쓸 때 고를 수 있는 분류 (영상은 새 글에서 빼요. 이미 영상인 글을 고칠 때는 그대로 보여요)
    private var availableCategories: [PostCategory] {
        isEditing ? PostCategory.allCases : [.program, .freeTime]
    }

    private var petName: String? { store.pets.first { $0.id == petID }?.name }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    petSection

                    sectionTitle("분류")
                    Picker("분류", selection: $category) {
                        ForEach(availableCategories, id: \.self) { category in
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

                    if !isLegacyGroupPost {
                        sectionTitle("건강 기록")
                        HealthInputFields(state: $healthInput)
                        Text("저장하면 홈의 건강 기록에도 함께 기록돼요.")
                            .font(AppTheme.Typography.captionRegular)
                            .foregroundStyle(AppTheme.subText)
                    }

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
            .task(id: petID) { loadHealthInput() }
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

    // MARK: 반려견 (한 마리)

    /// 정해진 반려견이면 이름만 보여주고, 정해지지 않았으면 한 마리를 고르게 해요.
    @ViewBuilder
    private var petSection: some View {
        if let name = petName, !needsPetChoice {
            Label("\(name)의 알림장", systemImage: "pawprint.fill")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.text)
        } else if needsPetChoice {
            sectionTitle("반려견 선택")
            if taggablePets.isEmpty {
                Text("오늘 등원한 반려견이 없어요")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.small) {
                        ForEach(taggablePets) { pet in
                            petChip(pet)
                        }
                    }
                }
            }
        }
    }

    private func petChip(_ pet: Pet) -> some View {
        let isOn = selectedPetID == pet.id
        return Button {
            selectedPetID = pet.id
        } label: {
            Text(pet.name)
                .font(AppTheme.Typography.headline)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// 고른 반려견의 그날 건강 기록이 있으면 불러오고, 없으면 최근 몸무게를 시작값으로 씁니다.
    private func loadHealthInput() {
        guard let petID, !isLegacyGroupPost else { return }
        let day: Date
        if case .edit(let post) = mode { day = post.date } else { day = .now }
        let record = health.record(petID: petID, on: day)
        // 이미 입력하던 값은 지우지 않고, 처음 불러올 때와 반려견을 바꿨을 때만 채워요.
        if !didLoadHealth || !healthInput.hasAnyInput {
            healthInput = HealthInputState(record: record, suggestedWeight: health.latestWeight(petID: petID))
            didLoadHealth = true
        }
    }

    /// 고를 수 있는 반려견 = 승인된 반려견 중, 원장·선생님은 오늘 등원해 있는 아이만
    private var taggablePets: [Pet] {
        guard let user = session.currentUser else { return [] }
        return TeacherHomeViewModel.todaysPets(store.visiblePets(for: user), for: user, attendance: attendance)
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
        switch mode {
        case .create:
            guard Permissions.canWritePost(user) else {
                errorMessage = String(localized: "사진글을 올릴 권한이 없어요.")
                return
            }
            guard let petID else { return }
            let now = Date.now
            store.save(post: Post(id: UUID().uuidString, authorID: user.id, text: trimmedText,
                                  photos: photos, taggedPetIDs: [petID], date: now,
                                  category: category))
            saveHealth(petID: petID, day: now, user: user)
        case .edit(let original):
            guard Permissions.canEdit(original, by: user) else {
                errorMessage = String(localized: "이 글을 수정할 권한이 없어요.")
                return
            }
            var post = original
            post.text = trimmedText
            post.photos = photos
            store.save(post: post)
            if let petID, !isLegacyGroupPost {
                saveHealth(petID: petID, day: original.date, user: user)
            }
        }
        dismiss()
    }

    /// 켜 둔 건강 기록(응가·몸무게·식사량)을 홈의 건강 기록에도 함께 저장합니다.
    private func saveHealth(petID: String, day: Date, user: User) {
        guard Permissions.canEditHealthRecords(user),
              let record = healthInput.makeRecord(existing: health.record(petID: petID, on: day),
                                                  petID: petID, day: day, recordedByID: user.id)
        else { return }
        health.save(record)
    }
}

#Preview("사진글 작성") {
    PostEditorView(mode: .create)
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
}

#Preview("사진글 수정 (다크)") {
    PostEditorView(mode: .edit(SampleData.posts[0]))
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
        .preferredColorScheme(.dark)
}
