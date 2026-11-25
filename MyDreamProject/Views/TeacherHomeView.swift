import SwiftUI

/// 유치원 선생님이 보는 첫 화면
struct TeacherHomeView: View {
    @State private var viewModel: TeacherHomeViewModel
    @State private var isEditingName = false
    @State private var nameDraft = ""
    @State private var sheetTarget: SheetTarget?
    /// 등원한 강아지 / 등원 대기 목록을 펼쳐 둘지 (앱을 다시 열면 펼쳐진 상태로 시작해요)
    @State private var showsPresent = true
    @State private var showsExpected = true

    /// 홈에서 여는 창: 강아지의 건강 기록 / 강아지를 태그한 알림장 작성
    private enum SheetTarget: Identifiable {
        case health(petID: String)
        case notebook(Dog)

        var id: String {
            switch self {
            case .health(let petID): "health-\(petID)"
            case .notebook(let dog): "notebook-\(dog.id)"
            }
        }
    }

    /// 유치원 이름 수정 버튼을 보여줄지 (원장만 true)
    private let canEditKindergartenName: Bool
    /// 보호자 경고 관리 카드를 보여줄지 (원장만 true)
    private let canManageWarnings: Bool
    /// 건강 기록(응가·몸무게·식사량) 카드를 보여줄지 (원장·선생님만 true)
    private let showsHealthRecords: Bool
    /// 승인된 반려견 목록. 넘겨주면 등원 목록이 이 반려견들과 이어져요.
    private let pets: [Pet]?

    init(viewModel: TeacherHomeViewModel, canEditKindergartenName: Bool = true, canManageWarnings: Bool = false,
         showsHealthRecords: Bool = false,
         pets: [Pet]? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.canEditKindergartenName = canEditKindergartenName
        self.canManageWarnings = canManageWarnings
        self.showsHealthRecords = showsHealthRecords
        self.pets = pets
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                listSection
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        // 승인된 반려견이 바뀌면 등원 목록도 함께 맞춥니다.
        .onChange(of: pets, initial: true) { _, newPets in
            syncDogs(with: newPets)
        }
        .sheet(item: $sheetTarget) { target in
            switch target {
            case .health(let petID):
                PetHealthLogView(petID: petID)
            case .notebook(let dog):
                PostEditorView(mode: .create, initialTaggedPetIDs: dog.petID.map { [$0] } ?? [])
            }
        }
    }

    // MARK: - 화면 조각

    /// 머리말과 요약 카드를 살짝 겹쳐서 보여줌
    private var headerSection: some View {
        VStack(spacing: -30) {
            hero
            summaryCard
                .padding(.horizontal, 16)
        }
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            extraCards
            presentSection
            expectedSection
        }
        .padding(16)
        .padding(.top, 4)
    }

    /// 원장·선생님에게만 보이는 카드 (경고 관리, 건강 기록)
    @ViewBuilder
    private var extraCards: some View {
        if showsHealthRecords {
            // 입학·예약·상담·이용권·출석·반려견 상세로 들어가는 메뉴
            StaffToolsCard()
        }
        if canManageWarnings {
            WarningEntryCard()
        }
        if showsHealthRecords {
            HealthRecordsCard(petIDs: nil, canEdit: true, attendingPetIDs: viewModel.presentPetIDs)
        }
    }

    @ViewBuilder
    private var presentSection: some View {
        sectionTitle("현재 등원한 강아지", count: viewModel.presentDogs.count, isExpanded: $showsPresent)
        if showsPresent {
            if viewModel.presentDogs.isEmpty {
                emptyText("아직 등원한 강아지가 없어요")
            } else {
                ForEach(viewModel.presentDogs) { dog in
                    presentRow(dog)
                }
            }
        }
    }

    @ViewBuilder
    private var expectedSection: some View {
        sectionTitle("등원 대기", count: viewModel.expectedDogs.count, isExpanded: $showsExpected)
            .padding(.top, 8)
        if showsExpected {
            if viewModel.expectedDogs.isEmpty {
                emptyText("대기 중인 강아지가 없어요")
            } else {
                ForEach(viewModel.expectedDogs) { dog in
                    expectedRow(dog)
                }
            }
        }
    }

    private func syncDogs(with newPets: [Pet]?) {
        if let newPets { viewModel.sync(with: newPets) }
    }

    // MARK: - 머리말

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("안녕하세요, 선생님 🐾")
                    .font(AppTheme.Typography.footnoteBold)
                    .opacity(0.9)
                HStack(spacing: 4) {
                    Text(viewModel.kindergartenName)
                        .font(AppTheme.Typography.heroTitle)
                        .lineLimit(2)
                    if canEditKindergartenName {
                        Button {
                            nameDraft = viewModel.kindergartenName
                            isEditingName = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("유치원 이름 수정")
                    }
                }
                Text("댕답개 배우개")
                    .font(AppTheme.Typography.captionBold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.28), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("🐩")
                .font(.system(size: 52))
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 48)
        .alert("유치원 이름 수정", isPresented: $isEditingName) {
            TextField("유치원 이름", text: $nameDraft)
            Button("저장") { viewModel.renameKindergarten(to: nameDraft) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(TeacherHomeViewModel.maxNameLength)자까지 입력할 수 있어요.")
        }
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 34, bottomTrailingRadius: 34)
                .fill(AppTheme.hero)
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - 요약

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Text("\(viewModel.scheduledCount)")
                .font(AppTheme.Typography.statNumber)
                .foregroundStyle(AppTheme.button)
            VStack(alignment: .leading, spacing: 6) {
                Text("오늘 등원 예정")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Text("\(viewModel.arrivedCount)마리 등원 완료")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.subText)
                ProgressView(value: Double(viewModel.arrivedCount),
                             total: Double(max(viewModel.scheduledCount, 1)))
                    .tint(AppTheme.buttonShadow)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: AppTheme.cardShadow, radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 목록

    /// 제목을 누르면 아래 목록이 접히고 펼쳐져요.
    private func sectionTitle(_ title: LocalizedStringKey, count: Int, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.text)
                Text("\(count)").font(AppTheme.Typography.subheadlineBold).foregroundStyle(AppTheme.subText)
                Image(systemName: "chevron.down")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(isExpanded.wrappedValue ? String(localized: "누르면 접어요") : String(localized: "누르면 펼쳐요")))
    }

    private func emptyText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(AppTheme.Typography.subheadline)
            .foregroundStyle(AppTheme.subText)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    /// 건강 기록을 쓸 수 있는 강아지는 이름 쪽을 누르면 그 아이의 건강 기록 화면이 열려요.
    @ViewBuilder
    private func dogHeader(_ dog: Dog, detail: String) -> some View {
        if showsHealthRecords, let petID = dog.petID {
            Button {
                sheetTarget = .health(petID: petID)
            } label: {
                dogInfo(dog, detail: detail, showsHealthHint: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("건강 기록 열기")
        } else {
            dogInfo(dog, detail: detail)
        }
    }

    private func dogInfo(_ dog: Dog, detail: String, showsHealthHint: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "dog.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.softButtonText)
                .frame(width: 46, height: 46)
                .background(AppTheme.avatar, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(dog.name)
                    .font(AppTheme.Typography.title3Heavy)
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(AppTheme.Typography.captionRegular)
                    .foregroundStyle(AppTheme.subText)
            }
            Spacer(minLength: 0)
            if showsHealthHint {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(AppTheme.softButtonText)
                    .accessibilityHidden(true)
            }
        }
    }

    private func presentRow(_ dog: Dog) -> some View {
        var detail = dog.breed
        if let time = dog.checkInTime {
            let timeText = time.formatted(date: .omitted, time: .shortened)
            detail = String(localized: "\(dog.breed) · \(timeText) 등원")
        }
        return VStack(spacing: 12) {
            dogHeader(dog, detail: detail)
            HStack(spacing: 10) {
                Button {
                    sheetTarget = .notebook(dog)
                } label: {
                    Label("알림장 작성", systemImage: "square.and.pencil")
                }
                .buttonStyle(SoftButtonStyle())

                Button {
                    viewModel.checkOut(dog)
                } label: {
                    Label("하원", systemImage: "house.fill")
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    private func expectedRow(_ dog: Dog) -> some View {
        HStack(spacing: 10) {
            dogHeader(dog, detail: dog.breed)
            Button("등원") {
                viewModel.checkIn(dog)
            }
            .buttonStyle(GradientButtonStyle())
            .frame(width: 88)
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }
}

/// 원장 홈의 "보호자 경고 관리" 카드. 누르면 경고를 세는 화면이 열려요.
private struct WarningEntryCard: View {
    @Environment(AccountStore.self) private var accounts
    @State private var showing = false

    private var warnedCount: Int {
        accounts.parents.filter { $0.warningCount > 0 && $0.status == .active }.count
    }

    private var suspendedCount: Int {
        accounts.parents.filter { $0.status == .suspended }.count
    }

    var body: some View {
        Button {
            showing = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .onAppear { accounts.reloadParents() }
        .sheet(isPresented: $showing, onDismiss: { accounts.reloadParents() }) {
            WarningManagementView()
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.statusPending)
            VStack(alignment: .leading, spacing: 2) {
                Text("보호자 경고 관리")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Text("경고 중 \(warnedCount)명 · 이용 중단 \(suspendedCount)명")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(AppTheme.subText)
        }
        .padding(14)
        .frame(minHeight: 44)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }
}

#Preview("라이트") {
    TeacherHomeView(viewModel: .sample)
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
}

#Preview("원장 (경고 관리 포함)") {
    TeacherHomeView(viewModel: .sample, canManageWarnings: true)
        .environment(AccountStore())
        .environment(NotebookStore())
        .environment(NotificationStore())
        .environment(SessionStore(currentUser: SampleData.owner))
}

#Preview("선생님용 (이름 수정 불가)") {
    TeacherHomeView(viewModel: .sample, canEditKindergartenName: false)
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
}

#Preview("다크") {
    TeacherHomeView(viewModel: .sample)
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}

#Preview("등원한 강아지 없음") {
    TeacherHomeView(
        viewModel: TeacherHomeViewModel(
            kindergartenName: "댕댕이 유치원",
            dogs: [Dog(name: "콩이", breed: "포메라니안")],
            nameStore: InMemoryKindergartenNameStore()
        )
    )
    .environment(SessionStore(currentUser: SampleData.teacher))
    .environment(NotebookStore())
}
