import SwiftUI

/// 사진첩: 알림장 글의 사진·영상을 모아 3열 격자로 보여줍니다.
/// 위쪽 분류: 전체 / 프로그램 / 자유시간 / 영상
struct AlbumView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var selectedCategory: PostCategory?
    @State private var isSelecting = false
    @State private var selectedPhotoIDs: Set<String> = []
    @State private var viewerStart: ViewerStart?
    @State private var resultMessage: String?
    @State private var isSaving = false

    private struct ViewerStart: Identifiable { let id: String }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            if let user = session.currentUser {
                content(for: user)
            }
        }
    }

    private func content(for user: User) -> some View {
        let items = store.albumPhotos(for: user, category: selectedCategory)
        let chosen = items.filter { selectedPhotoIDs.contains($0.id) }
        return VStack(spacing: 0) {
            filterBar
            if items.isEmpty {
                Text("볼 수 있는 사진이 아직 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(items) { item in cell(item) }
                    }
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("사진첩")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !items.isEmpty {
                    Button(isSelecting ? "완료" : "선택") {
                        isSelecting.toggle()
                        selectedPhotoIDs = []
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting { selectionBar(chosen) }
        }
        .fullScreenCover(item: $viewerStart) { start in
            PhotoViewerView(startID: start.id, category: selectedCategory)
        }
        .alert("사진 저장", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
        .onChange(of: selectedCategory) { _, _ in selectedPhotoIDs = [] }
    }

    // MARK: 분류 (전체 / 프로그램 / 자유시간 / 영상)

    private var filterBar: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            filterChip(title: "전체", isOn: selectedCategory == nil) { selectedCategory = nil }
            ForEach(PostCategory.allCases, id: \.self) { category in
                filterChip(title: category.displayName, isOn: selectedCategory == category) {
                    selectedCategory = category
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.small)
    }

    private func filterChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: 격자 한 칸

    private func cell(_ item: AlbumPhoto) -> some View {
        let isVideoPost = store.post(id: item.postID)?.category == .video
        return Button {
            if isSelecting {
                if selectedPhotoIDs.contains(item.id) {
                    selectedPhotoIDs.remove(item.id)
                } else {
                    selectedPhotoIDs.insert(item.id)
                }
            } else {
                viewerStart = ViewerStart(id: item.id)
            }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { PhotoImageView(source: item.photo.source) }
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    if isVideoPost {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isSelecting {
                        Image(systemName: selectedPhotoIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, selectedPhotoIDs.contains(item.id) ? Color.accentColor : .black.opacity(0.35))
                            .font(.title3)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isVideoPost ? "영상" : "사진")
    }

    // MARK: 여러 장 저장·공유

    private func selectionBar(_ chosen: [AlbumPhoto]) -> some View {
        // 영상은 저장만 되고, 공유는 사진만 한 번에 보낼 수 있어요.
        let shareable = chosen.filter { item in
            if case .video = item.photo.source { return false }
            return true
        }
        return HStack(spacing: 10) {
            Text("\(chosen.count)개 선택")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            Spacer()
            ShareLink(items: shareable.map { SharablePhoto(source: $0.photo.source) },
                      preview: { _ in SharePreview("댕답개 배우개 사진") }) {
                Label("공유", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SoftButtonStyle())
            .frame(width: 100)
            .disabled(shareable.isEmpty)

            Button {
                isSaving = true
                Task {
                    resultMessage = await PhotoSaver.save(chosen.map(\.photo.source))
                    isSaving = false
                    isSelecting = false
                    selectedPhotoIDs = []
                }
            } label: {
                Label("저장", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(GradientButtonStyle())
            .frame(width: 100)
            .disabled(chosen.isEmpty || isSaving)
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview("원장 (전체)") {
    AlbumView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
}

#Preview("보호자 (내 반려견 글만)") {
    AlbumView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
}

#Preview("선생님 (다크)") {
    AlbumView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
