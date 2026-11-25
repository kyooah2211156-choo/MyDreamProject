import SwiftUI

/// 사진첩: 알림장 글의 사진·영상을 모아 3열 격자로 보여줍니다.
/// 위쪽 분류: 전체 / 프로그램 / 자유시간 / 영상
struct AlbumView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @State private var selectedCategory: PostCategory?
    /// 앨범 보기 방식: 전체 / 강아지별 개인 앨범 / 날짜별 활동 앨범
    @State private var albumMode: AlbumMode = .all
    @State private var filterPetID: String?
    @State private var filterDay: Date?
    @State private var isSelecting = false
    @State private var selectedPhotoIDs: Set<String> = []
    @State private var viewerStart: ViewerStart?
    @State private var resultMessage: String?
    @State private var isSaving = false
    @State private var isAdding = false

    private struct ViewerStart: Identifiable { let id: String }

    private enum AlbumMode: CaseIterable {
        case all, pet, date

        var title: String {
            switch self {
            case .all: String(localized: "모아보기")
            case .pet: String(localized: "강아지별")
            case .date: String(localized: "날짜별")
            }
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            if let user = session.currentUser {
                content(for: user)
            }
        }
    }

    private func content(for user: User) -> some View {
        let filter = currentFilter(for: user)
        let items = store.albumPhotos(for: user, category: selectedCategory, filter: filter)
        let chosen = items.filter { selectedPhotoIDs.contains($0.id) }
        return VStack(spacing: 0) {
            filterBar
            modeBar
            modeDetailBar(for: user)
            if items.isEmpty {
                Text("볼 수 있는 사진이 아직 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if albumMode == .date && filterDay == nil {
                        // 날짜별 활동 앨범: 날짜마다 묶어서 보여줘요.
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(dayGroups(items), id: \.day) { group in
                                Text(group.day.formatted(.dateTime.year().month().day().weekday(.abbreviated)))
                                    .font(AppTheme.Typography.headline)
                                    .foregroundStyle(AppTheme.text)
                                    .padding(.horizontal, AppTheme.Spacing.large)
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(group.items) { item in cell(item) }
                                }
                            }
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(items) { item in cell(item) }
                        }
                    }
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("사진첩")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if Permissions.canWritePost(user) {
                    Button { isAdding = true } label: {
                        Label("사진 추가", systemImage: "plus")
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            // iOS 26부터 이웃한 버튼이 한 덩어리로 묶이므로, 간격을 넣어 따로 보이게 합니다.
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !items.isEmpty {
                    Button(isSelecting ? String(localized: "완료") : String(localized: "선택")) {
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
        .sheet(isPresented: $isAdding) {
            AlbumPhotoAddView(initialCategory: selectedCategory)
        }
        .fullScreenCover(item: $viewerStart) { start in
            PhotoViewerView(startID: start.id, category: selectedCategory, filter: currentFilter(for: session.currentUser))
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
        .onChange(of: albumMode) { _, _ in selectedPhotoIDs = [] }
        .onChange(of: filterPetID) { _, _ in selectedPhotoIDs = [] }
        .onChange(of: filterDay) { _, _ in selectedPhotoIDs = [] }
    }

    // MARK: 분류 (전체 / 프로그램 / 자유시간 / 영상)

    private var filterBar: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            filterChip(title: String(localized: "전체"), isOn: selectedCategory == nil) { selectedCategory = nil }
            ForEach(PostCategory.allCases, id: \.self) { category in
                filterChip(title: category.displayName, isOn: selectedCategory == category) {
                    selectedCategory = category
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.small)
    }

    // MARK: 보기 방식 (모아보기 / 강아지별 / 날짜별)

    private var modeBar: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(AlbumMode.allCases, id: \.self) { mode in
                let isOn = albumMode == mode
                Button { albumMode = mode } label: {
                    Text(mode.title)
                        .font(AppTheme.Typography.caption)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(isOn ? AppTheme.softButtonText : AppTheme.subText)
                        .background(isOn ? AnyShapeStyle(AppTheme.softButton) : AnyShapeStyle(Color.clear), in: Capsule())
                        .overlay { Capsule().stroke(AppTheme.softButtonText.opacity(isOn ? 0.5 : 0.2), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.bottom, AppTheme.Spacing.small)
    }

    @ViewBuilder
    private func modeDetailBar(for user: User) -> some View {
        switch albumMode {
        case .all:
            EmptyView()
        case .pet:
            // 보호자에게는 내 반려견만, 원장·선생님에게는 승인된 반려견 전체가 보여요.
            let pets = store.visiblePets(for: user)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.small) {
                    ForEach(pets) { pet in
                        let isOn = (filterPetID ?? pets.first?.id) == pet.id
                        Button { filterPetID = pet.id } label: {
                            Text(pet.name)
                                .font(AppTheme.Typography.headline)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                                .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.large)
            }
            .padding(.bottom, AppTheme.Spacing.small)
        case .date:
            HStack {
                if filterDay != nil {
                    DatePicker("날짜", selection: Binding(get: { filterDay ?? .now },
                                                         set: { filterDay = Calendar.current.startOfDay(for: $0) }),
                               in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                    Button("전체 날짜") { filterDay = nil }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.softButtonText)
                        .frame(minHeight: 44)
                } else {
                    Button { filterDay = Calendar.current.startOfDay(for: .now) } label: {
                        Label("날짜 고르기", systemImage: "calendar")
                            .font(AppTheme.Typography.caption)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .foregroundStyle(AppTheme.softButtonText)
                            .background(AppTheme.softButton, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.bottom, AppTheme.Spacing.small)
        }
    }

    private func currentFilter(for user: User?) -> AlbumFilter {
        switch albumMode {
        case .all:
            return AlbumFilter()
        case .pet:
            guard let user else { return AlbumFilter() }
            return AlbumFilter(petID: filterPetID ?? store.visiblePets(for: user).first?.id)
        case .date:
            return AlbumFilter(day: filterDay)
        }
    }

    /// 사진을 글의 날짜별로 묶습니다. (최신 날짜가 위)
    private func dayGroups(_ items: [AlbumPhoto]) -> [(day: Date, items: [AlbumPhoto])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: store.post(id: item.postID)?.date ?? .distantPast)
        }
        return grouped.keys.sorted(by: >).map { (day: $0, items: grouped[$0] ?? []) }
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
        .accessibilityLabel(isVideoPost ? String(localized: "영상") : String(localized: "사진"))
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
                      preview: { _ in SharePreview(String(localized: "댕답개 배우개 사진")) }) {
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
