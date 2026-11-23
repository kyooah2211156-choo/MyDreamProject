import SwiftUI
import PhotosUI

/// 사진첩에서 바로 사진·영상 추가 (원장·선생님).
/// 반려견과 분류(프로그램 / 자유시간 / 영상)를 고르고 사진을 고르면, 내용 없는 사진글로 저장됩니다.
struct AlbumPhotoAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @Environment(TeacherHomeViewModel.self) private var attendance: TeacherHomeViewModel?

    @State private var petID: String?
    @State private var category: PostCategory
    @State private var photos: [PostPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false

    private static let maxPhotos = 10

    /// 사진첩에서 보고 있던 분류가 있으면 그 분류로 시작합니다.
    init(initialCategory: PostCategory? = nil) {
        _category = State(initialValue: initialCategory ?? .program)
    }

    private var isVideo: Bool { category == .video }
    private var mediaName: String { isVideo ? String(localized: "영상") : String(localized: "사진") }

    private var pets: [Pet] {
        guard let user = session.currentUser else { return [] }
        return TeacherHomeViewModel.todaysPets(store.visiblePets(for: user), for: user, attendance: attendance)
    }

    private var canSave: Bool { petID != nil && !photos.isEmpty && !isLoading }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    sectionTitle("반려견 선택")
                    if pets.isEmpty {
                        Text("오늘 등원한 반려견이 없어요")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.subText)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.small) {
                                ForEach(pets) { petChip($0) }
                            }
                        }
                    }

                    sectionTitle("분류")
                    Picker("분류", selection: $category) {
                        ForEach(PostCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    sectionTitle("\(mediaName) \(photos.count)/\(Self.maxPhotos)")
                    photoStrip
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("사진첩에 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(!canSave)
                }
            }
            // 사진과 영상은 섞을 수 없어서, 분류를 바꾸면 고른 것을 비웁니다.
            .onChange(of: category) { old, new in
                if (old == .video) != (new == .video) { photos = [] }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPicked(items) }
            }
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.text)
    }

    private func petChip(_ pet: Pet) -> some View {
        let isOn = petID == pet.id
        return Button { petID = pet.id } label: {
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

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if photos.count < Self.maxPhotos {
                    PhotosPicker(selection: $pickerItems,
                                 maxSelectionCount: Self.maxPhotos - photos.count,
                                 matching: isVideo ? PHPickerFilter.videos : PHPickerFilter.images) {
                        VStack(spacing: 6) {
                            if isLoading {
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
        isLoading = true
        defer { isLoading = false }
        for item in items {
            guard photos.count < Self.maxPhotos else { break }
            if isVideo {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    photos.append(PostPhoto(id: UUID().uuidString, source: .video(movie.url)))
                }
            } else if let data = try? await item.loadTransferable(type: Data.self) {
                photos.append(PostPhoto(id: UUID().uuidString, source: .data(PhotoRenderer.compressed(data))))
            }
        }
        pickerItems = []
    }

    private func save() {
        guard let user = session.currentUser, Permissions.canWritePost(user),
              let petID, !photos.isEmpty else { return }
        store.save(post: Post(id: UUID().uuidString, authorID: user.id, text: "",
                              photos: photos, taggedPetIDs: [petID], date: .now,
                              category: category))
        dismiss()
    }
}

#Preview("사진첩에 추가") {
    AlbumPhotoAddView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
}
