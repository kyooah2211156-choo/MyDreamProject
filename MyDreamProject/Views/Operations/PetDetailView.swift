import SwiftUI
import PhotosUI

/// 반려견 개인 상세 페이지: 프로필, 연락처, 건강·식이, 특이사항, 등·하원, 건강·훈련 기록, 알림장·사진첩을 한곳에서 봐요.
/// 원장·선생님은 승인된 반려견 전체, 보호자는 내 반려견만 열 수 있어요.
struct PetDetailSheet: View {
    let petID: String

    var body: some View {
        OpsSheet(title: "반려견 상세") {
            PetDetailContent(petID: petID)
        }
    }
}

struct PetDetailContent: View {
    let petID: String

    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(PetDetailStore.self) private var details
    @Environment(AttendanceStore.self) private var attendance
    @Environment(HealthRecordStore.self) private var health
    @Environment(TrainingProgressStore.self) private var progress
    @Environment(AdmissionStore.self) private var admission
    @State private var pickerItem: PhotosPickerItem?
    @State private var editing = false
    @State private var showingHealthLog = false

    private var pet: Pet? { notebook.pets.first { $0.id == petID } }

    var body: some View {
        if let user = session.currentUser, let pet, Permissions.canViewDetail(of: pet, by: user) {
            let info = details.detail(petID: petID)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header(pet, info: info, user: user)
                contactCard(pet, info: info, user: user)
                careCard(pet, info: info)
                behaviorCard(pet, info: info)
                attendanceCard
                healthCard(user: user)
                trainingCard
                notebookCard(user: user)
            }
            .sheet(isPresented: $editing) { PetDetailEditorView(pet: pet, initial: info) }
            .sheet(isPresented: $showingHealthLog) { PetHealthLogView(petID: petID) }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       Permissions.canEditDetail(of: pet, by: user) {
                        notebook.updateProfilePhoto(petID: petID, photo: .data(PhotoRenderer.compressed(data)))
                    }
                    pickerItem = nil
                }
            }
        } else {
            OpsEmptyCard(text: "이 반려견의 상세 정보를 볼 수 없어요")
        }
    }

    // MARK: 프로필

    private func header(_ pet: Pet, info: PetDetailInfo, user: User) -> some View {
        HStack(spacing: 16) {
            Group {
                if let photo = pet.profilePhoto {
                    PhotoImageView(source: photo)
                } else {
                    AppTheme.avatar.overlay {
                        Image(systemName: "dog.fill").font(.largeTitle).foregroundStyle(AppTheme.softButtonText)
                    }
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(pet.name)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.text)
                Text(pet.breed)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                HStack(spacing: 6) {
                    PetStatusBadge(status: pet.status)
                    if admission.isAdmitted(petID: petID) {
                        OpsPill(text: String(localized: "입학 완료"), color: AppTheme.buttonShadow)
                    }
                }
                if Permissions.canEditDetail(of: pet, by: user) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("프로필 사진 바꾸기")
                            .font(AppTheme.Typography.caption)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .foregroundStyle(AppTheme.softButtonText)
                            .background(AppTheme.softButton, in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .opsCard()
    }

    // MARK: 연락처

    private func contactCard(_ pet: Pet, info: PetDetailInfo, user: User) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                OpsSectionTitle(text: "보호자 · 비상 연락처")
                Spacer()
                if Permissions.canEditDetail(of: pet, by: user) {
                    Button("수정") { editing = true }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.softButtonText)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            OpsInfoRow(title: String(localized: "보호자"), value: notebook.authorName(pet.ownerID))
            OpsInfoRow(title: String(localized: "연락처"), value: info.guardianPhone)
            OpsInfoRow(title: String(localized: "비상 연락"), value: info.emergencyName)
            OpsInfoRow(title: String(localized: "비상 번호"), value: info.emergencyPhone)
        }
        .opsCard()
    }

    // MARK: 건강·식이

    private func careCard(_ pet: Pet, info: PetDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OpsSectionTitle(text: "알레르기 · 급여 · 병력")
            OpsInfoRow(title: String(localized: "알레르기"), value: pet.profile?.allergy ?? "")
            OpsInfoRow(title: String(localized: "급여 금지"), value: info.forbiddenFoods, emptyText: String(localized: "없음"))
            VStack(alignment: .leading, spacing: 6) {
                Text("복용 중인 약")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                if info.medications.isEmpty {
                    Text("복용 중인 약이 없어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                }
                ForEach(info.medications) { medication in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(medication.name) · \(medication.dosage)")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.text)
                        if !medication.note.isEmpty {
                            Text(medication.note)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.subText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(AppTheme.softButton.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            OpsInfoRow(title: String(localized: "기존 질병"), value: info.illnessHistory, emptyText: String(localized: "없음"))
            OpsInfoRow(title: String(localized: "수술 이력"), value: info.surgeryHistory, emptyText: String(localized: "없음"))
            OpsInfoRow(title: String(localized: "건강상태"), value: pet.profile?.healthCondition ?? "")
        }
        .opsCard()
    }

    // MARK: 특이사항

    private func behaviorCard(_ pet: Pet, info: PetDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OpsSectionTitle(text: "특이사항")
            HStack(spacing: 8) {
                OpsPill(text: info.isAggressive ? String(localized: "공격성 주의") : String(localized: "공격성 없음"),
                        color: info.isAggressive ? AppTheme.statusRejected : AppTheme.statusApproved)
                OpsPill(text: info.hasSeparationAnxiety ? String(localized: "분리불안 있음") : String(localized: "분리불안 없음"),
                        color: info.hasSeparationAnxiety ? AppTheme.statusPending : AppTheme.statusApproved)
            }
            OpsInfoRow(title: String(localized: "성향"), value: pet.profile?.temperament ?? "")
            OpsInfoRow(title: String(localized: "메모"), value: info.behaviorNote, emptyText: String(localized: "없음"))
        }
        .opsCard()
    }

    // MARK: 등원·하원 기록

    private var attendanceCard: some View {
        let entries = attendance.history(petID: petID).prefix(7)
        return VStack(alignment: .leading, spacing: 8) {
            OpsSectionTitle(text: "등원 · 하원 기록")
            if entries.isEmpty {
                Text("아직 기록이 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
            }
            ForEach(Array(entries)) { entry in
                HStack {
                    Text(entry.day.formatted(.dateTime.month().day().weekday(.abbreviated)))
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.text)
                        .frame(width: 96, alignment: .leading)
                    Text("등원 \(entry.checkIn.formatted(date: .omitted, time: .shortened))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                    Spacer()
                    Text(entry.checkOut.map { String(localized: "하원 \($0.formatted(date: .omitted, time: .shortened))") }
                         ?? String(localized: "유치원에 있어요"))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(entry.checkOut == nil ? AppTheme.statusPending : AppTheme.subText)
                }
            }
        }
        .opsCard()
    }

    // MARK: 건강 기록

    private func healthCard(user: User) -> some View {
        let records = health.records.filter { $0.petID == petID }.sorted { $0.date > $1.date }.prefix(5)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                OpsSectionTitle(text: "건강 기록")
                Spacer()
                if Permissions.canEditHealthRecords(user) {
                    Button("기록하기") { showingHealthLog = true }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.softButtonText)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            if records.isEmpty {
                Text("아직 기록이 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
            }
            ForEach(Array(records)) { record in
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.subText)
                    HealthMetricPills(record: record)
                }
            }
        }
        .opsCard()
    }

    // MARK: 훈련 기록

    private var trainingCard: some View {
        let all = Training.samples + details.customTrainings(petID: petID).map(\.asTraining)
        let rows = all.compactMap { training -> (Training, Int)? in
            let percent = progress.percent(petID: petID, trainingID: training.id)
            return percent > 0 ? (training, percent) : nil
        }
        return VStack(alignment: .leading, spacing: 10) {
            OpsSectionTitle(text: "훈련 기록")
            if rows.isEmpty {
                Text("아직 훈련 기록이 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
            }
            ForEach(rows, id: \.0.id) { training, percent in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(training.title)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Text("\(percent)%")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.subText)
                    }
                    ProgressView(value: Double(percent), total: 100).tint(AppTheme.buttonShadow)
                    if let last = progress.history(petID: petID, trainingID: training.id).first {
                        Text("\(last.date.formatted(.dateTime.month().day())) 기록 · \(notebook.authorName(last.recordedByID))")
                            .font(AppTheme.Typography.caption2)
                            .foregroundStyle(AppTheme.subText)
                    }
                }
            }
        }
        .opsCard()
    }

    // MARK: 알림장·사진첩

    private func notebookCard(user: User) -> some View {
        let posts = notebook.visiblePosts(for: user).filter { $0.isPublished && $0.taggedPetIDs.contains(petID) }
        let photos = posts.flatMap { post in post.photos.map { AlbumPhoto(photo: $0, postID: post.id) } }
        return VStack(alignment: .leading, spacing: 10) {
            OpsSectionTitle(text: "알림장 · 사진첩")
            if photos.isEmpty {
                Text("아직 올라온 사진이 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos.prefix(10)) { item in
                            NavigationLink {
                                PostDetailView(postID: item.postID)
                            } label: {
                                PhotoImageView(source: item.photo.source)
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .accessibilityLabel("사진 보기")
                        }
                    }
                }
            }
            ForEach(posts.prefix(3)) { post in
                NavigationLink {
                    PostDetailView(postID: post.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.text)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(2)
                        Text("\(notebook.authorName(post.authorID)) · \(post.date.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.subText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(AppTheme.softButton.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .opsCard()
    }
}

/// 연락처·급여 금지 음식·복용약·병력·특이사항 입력 창
struct PetDetailEditorView: View {
    let pet: Pet

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(PetDetailStore.self) private var details
    @State private var info: PetDetailInfo
    @State private var showErrors = false

    init(pet: Pet, initial: PetDetailInfo) {
        self.pet = pet
        _info = State(initialValue: initial)
    }

    /// 전화번호로 쓸 수 있는 글자인지 (비어 있으면 괜찮아요)
    private func isValidPhone(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespaces)
        if clean.isEmpty { return true }
        let digits = clean.filter(\.isNumber)
        return digits.count >= 8 && digits.count <= 12 && clean.allSatisfy { $0.isNumber || "-+ ".contains($0) }
    }

    private var invalidFields: [String] {
        var result: [String] = []
        if !isValidPhone(info.guardianPhone) { result.append(String(localized: "보호자 연락처")) }
        if !isValidPhone(info.emergencyPhone) { result.append(String(localized: "비상 번호")) }
        return result
    }

    private var canEditBehavior: Bool { session.currentUser.map(Permissions.canEditBehavior) ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    group("보호자 · 비상 연락처") {
                        OpsField(placeholder: "보호자 연락처 (예: 010-1234-5678)", text: $info.guardianPhone, keyboard: .phonePad)
                        OpsField(placeholder: "비상 연락처 이름·관계", text: $info.emergencyName)
                        OpsField(placeholder: "비상 연락처 번호", text: $info.emergencyPhone, keyboard: .phonePad)
                    }
                    group("급여 금지 음식") {
                        OpsField(placeholder: "예: 초콜릿, 포도 (없으면 비워 두세요)", text: $info.forbiddenFoods, multiline: true)
                    }
                    group("복용 중인 약") {
                        ForEach($info.medications) { $medication in
                            VStack(spacing: 6) {
                                OpsField(placeholder: "약 이름", text: $medication.name)
                                OpsField(placeholder: "용량·횟수", text: $medication.dosage)
                                OpsField(placeholder: "급여 시 주의사항", text: $medication.note)
                                Button("이 약 삭제", role: .destructive) {
                                    info.medications.removeAll { $0.id == medication.id }
                                }
                                .frame(minHeight: 44)
                            }
                            .padding(10)
                            .background(AppTheme.softButton.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
                        }
                        Button {
                            info.medications.append(PetMedication(id: UUID().uuidString, name: "", dosage: "", note: ""))
                        } label: {
                            Label("약 추가", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                    group("기존 질병 · 수술 이력") {
                        OpsField(placeholder: "기존 질병", text: $info.illnessHistory, multiline: true)
                        OpsField(placeholder: "수술 이력", text: $info.surgeryHistory, multiline: true)
                    }
                    group("공격성 · 분리불안 · 특이사항") {
                        Toggle("공격성이 있어요", isOn: $info.isAggressive).tint(AppTheme.buttonShadow)
                        Toggle("분리불안이 있어요", isOn: $info.hasSeparationAnxiety).tint(AppTheme.buttonShadow)
                        OpsField(placeholder: "그 밖의 특이사항", text: $info.behaviorNote, multiline: true)
                        if !canEditBehavior {
                            Text("보호자는 내용을 적을 수 있고, 공격성·분리불안 체크는 선생님이 확인해서 바꿔요.")
                                .font(AppTheme.Typography.captionRegular)
                                .foregroundStyle(AppTheme.subText)
                        }
                    }
                    if showErrors && !invalidFields.isEmpty {
                        Text("전화번호를 확인해 주세요: \(invalidFields.joined(separator: ", "))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.statusRejected)
                    }
                    Button("저장", action: save).buttonStyle(GradientButtonStyle())
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("\(pet.name) 상세 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            }
        }
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OpsSectionTitle(text: title)
            content()
        }
        .opsCard()
    }

    private func save() {
        showErrors = true
        guard let user = session.currentUser, Permissions.canEditDetail(of: pet, by: user), invalidFields.isEmpty else { return }
        var toSave = info
        toSave.medications = toSave.medications.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        // 보호자는 공격성·분리불안 체크를 바꿀 수 없어요. (기존 값을 그대로 둡니다)
        if !Permissions.canEditBehavior(user) {
            let current = details.detail(petID: pet.id)
            toSave.isAggressive = current.isAggressive
            toSave.hasSeparationAnxiety = current.hasSeparationAnxiety
        }
        details.save(detail: toSave)
        dismiss()
    }
}
