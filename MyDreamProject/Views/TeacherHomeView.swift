import SwiftUI

/// 유치원 선생님이 보는 첫 화면
struct TeacherHomeView: View {
    @State private var viewModel: TeacherHomeViewModel
    @State private var isEditingName = false
    @State private var nameDraft = ""

    init(viewModel: TeacherHomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 머리말과 요약 카드를 살짝 겹쳐서 보여줌
                VStack(spacing: -30) {
                    hero
                    summaryCard
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("현재 등원한 강아지", count: viewModel.presentDogs.count)
                    if viewModel.presentDogs.isEmpty {
                        emptyText("아직 등원한 강아지가 없어요")
                    } else {
                        ForEach(viewModel.presentDogs) { dog in
                            presentRow(dog)
                        }
                    }

                    sectionTitle("등원 대기", count: viewModel.expectedDogs.count)
                        .padding(.top, 8)
                    if viewModel.expectedDogs.isEmpty {
                        emptyText("대기 중인 강아지가 없어요")
                    } else {
                        ForEach(viewModel.expectedDogs) { dog in
                            expectedRow(dog)
                        }
                    }
                }
                .padding(16)
                .padding(.top, 4)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .alert(
            "알림장 작성",
            isPresented: Binding(
                get: { viewModel.dogForNotebook != nil },
                set: { if !$0 { viewModel.dogForNotebook = nil } }
            ),
            presenting: viewModel.dogForNotebook
        ) { _ in
            Button("확인", role: .cancel) {}
        } message: { dog in
            Text("\(dog.name)의 알림장 작성 화면은 다음 단계에서 만들어요.")
        }
    }

    // MARK: - 머리말

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("안녕하세요, 선생님 🐾")
                    .font(.footnote.weight(.bold))
                    .opacity(0.9)
                HStack(spacing: 4) {
                    Text(viewModel.kindergartenName)
                        .font(.title.weight(.black))
                        .lineLimit(2)
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
                Text("댕답개 배우개")
                    .font(.caption.weight(.bold))
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
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.button)
            VStack(alignment: .leading, spacing: 6) {
                Text("오늘 등원 예정")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text("\(viewModel.arrivedCount)마리 등원 완료")
                    .font(.caption.weight(.bold))
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

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.headline).foregroundStyle(AppTheme.text)
            Text("\(count)").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.subText)
        }
        .padding(.horizontal, 4)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppTheme.subText)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private func dogInfo(_ dog: Dog, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "dog.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.softButtonText)
                .frame(width: 46, height: 46)
                .background(AppTheme.avatar, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(dog.name)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            Spacer(minLength: 0)
        }
    }

    private func presentRow(_ dog: Dog) -> some View {
        var detail = dog.breed
        if let time = dog.checkInTime {
            detail += " · \(time.formatted(date: .omitted, time: .shortened)) 등원"
        }
        return VStack(spacing: 12) {
            dogInfo(dog, detail: detail)
            HStack(spacing: 10) {
                Button {
                    viewModel.dogForNotebook = dog
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
            dogInfo(dog, detail: dog.breed)
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

#Preview("라이트") {
    TeacherHomeView(viewModel: .sample)
}

#Preview("다크") {
    TeacherHomeView(viewModel: .sample)
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
}
