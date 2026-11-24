import SwiftUI
import PhotosUI

/// 반려견 등록 승인 화면 (원장·선생님). 신청 내용을 직접 확인하고 승인하거나 반려합니다.
struct PetApprovalView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @State private var rejectingPet: Pet?
    @State private var editingPet: Pet?
    @State private var showsPending = true
    @State private var showsApproved = false
    @State private var showsRejected = false

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canReviewPets(user) {
                    content(user)
                } else {
                    Text("원장님과 선생님만 볼 수 있어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background.ignoresSafeArea())
                }
            }
            .navigationTitle("등록 승인")
        }
    }

    private func content(_ user: User) -> some View {
        let pending = store.pendingPets
        let approved = store.pets.filter { $0.status == .approved }
        let rejected = store.pets.filter { $0.status == .rejected }
        return ScrollView {
            // 목록이 짧고, 승인하면 같은 반려견이 다른 섹션으로 옮겨 가요. LazyVStack은 이때 이전 카드를 재사용해 버튼이 먹통이 될 수 있어 VStack을 씁니다.
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                sectionTitle("승인 대기", count: pending.count, isExpanded: $showsPending)
                if showsPending {
                    if pending.isEmpty {
                        Text("대기 중인 신청이 없어요 😢")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.subText)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                    }
                    ForEach(pending) { pet in requestCard(pet, user: user) }
                }

                if !approved.isEmpty {
                    sectionTitle("승인 완료", count: approved.count, isExpanded: $showsApproved)
                    if showsApproved {
                        ForEach(approved) { pet in doneRow(pet, user: user) }
                    }
                }

                if !rejected.isEmpty {
                    sectionTitle("반려됨", count: rejected.count, isExpanded: $showsRejected)
                    if showsRejected {
                        ForEach(rejected) { pet in doneRow(pet, user: user) }
                    }
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .sheet(item: $rejectingPet) { pet in
            RejectReasonSheet(petName: pet.name) { reason in
                reject(pet, reason: reason, by: user)
            }
        }
        .sheet(item: $editingPet) { pet in
            EditAndApproveSheet(pet: pet) { edited in
                approveEdited(edited, by: user)
            }
        }
    }

    private func requestCard(_ pet: Pet, user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(pet.name) · \(pet.breed)")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                PetStatusBadge(status: pet.status)
            }
            Text("보호자 \(store.authorName(pet.ownerID))")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)

            PetProfileCard(pet: pet)

            Text("동물등록 번호 등은 직접 확인한 뒤에 승인해 주세요.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)

            HStack(spacing: 10) {
                Button("반려") { rejectingPet = pet }
                    .buttonStyle(SoftButtonStyle())
                Button("승인") { approve(pet, by: user) }
                    .buttonStyle(GradientButtonStyle())
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    private func doneRow(_ pet: Pet, user: User) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(pet.name) · \(pet.breed)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                PetStatusBadge(status: pet.status)
            }
            Text("보호자 \(store.authorName(pet.ownerID))")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
            if let reason = pet.rejectionReason {
                Text("반려 사유: \(reason)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.statusRejected)
            }
            if pet.status == .rejected, Permissions.canEditAndApprovePets(user) {
                Button("수정해서 승인") { editingPet = pet }
                    .buttonStyle(SoftButtonStyle())
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

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

    // MARK: 승인·반려 (처리하면 신청한 보호자에게 앱 안 알림이 갑니다)

    private func approve(_ pet: Pet, by user: User) {
        guard Permissions.canReviewPets(user),
              let updated = store.approvePet(id: pet.id, reviewerID: user.id) else { return }
        notifications.send(to: updated.requesterID,
                           title: String(localized: "반려견 등록이 승인됐어요"),
                           content: String(localized: "\(updated.name)의 등록이 승인되었습니다."))
    }

    private func approveEdited(_ pet: Pet, by user: User) {
        guard Permissions.canEditAndApprovePets(user),
              let updated = store.approveEditedPet(pet, reviewerID: user.id) else { return }
        notifications.send(to: updated.requesterID,
                           title: String(localized: "반려견 등록이 승인됐어요"),
                           content: String(localized: "\(updated.name)의 등록이 승인되었습니다."))
    }

    private func reject(_ pet: Pet, reason: String, by user: User) {
        guard Permissions.canReviewPets(user),
              let updated = store.rejectPet(id: pet.id, reviewerID: user.id, reason: reason) else { return }
        notifications.send(to: updated.requesterID,
                           title: String(localized: "반려견 등록이 반려됐어요"),
                           content: String(localized: "\(updated.name)의 등록이 반려되었습니다. 사유: \(updated.rejectionReason ?? reason)"))
    }
}

/// 반려된 반려견의 정보를 원장이 직접 고친 뒤 바로 승인하는 창
private struct EditAndApproveSheet: View {
    let pet: Pet
    let onApprove: (Pet) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var form: PetFormState
    @State private var photo: PhotoSource?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showErrors = false

    init(pet: Pet, onApprove: @escaping (Pet) -> Void) {
        self.pet = pet
        self.onApprove = onApprove
        _form = State(initialValue: PetFormState(pet: pet))
        _photo = State(initialValue: pet.profilePhoto)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if let reason = pet.rejectionReason {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("반려 사유")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.statusRejected)
                            Text(reason)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppTheme.Spacing.large)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                    }

                    photoSection

                    PetRegistrationFormView(form: $form, showErrors: showErrors)

                    if showErrors && !form.missingFields.isEmpty {
                        Text("빠진 항목: \(form.missingFields.map(\.title).joined(separator: ", "))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.statusRejected)
                    }

                    Button("수정하고 승인", action: approve)
                        .buttonStyle(GradientButtonStyle())
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("수정해서 승인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        photo = .data(PhotoRenderer.compressed(data))
                    }
                    pickerItem = nil
                }
            }
        }
    }

    // MARK: 프로필 사진 (선택)

    private var photoSection: some View {
        HStack(spacing: 14) {
            Group {
                if let photo {
                    PhotoImageView(source: photo)
                } else {
                    AppTheme.avatar.overlay {
                        Image(systemName: "dog.fill")
                            .font(.title)
                            .foregroundStyle(AppTheme.softButtonText)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text("프로필 사진 (선택)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                HStack(spacing: 8) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("사진 선택")
                            .font(AppTheme.Typography.caption)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .foregroundStyle(AppTheme.softButtonText)
                            .background(AppTheme.softButton, in: Capsule())
                    }
                    if photo != nil {
                        Button("사진 지우기") { photo = nil }
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.subText)
                            .frame(minHeight: 44)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    private func approve() {
        showErrors = true
        guard let profile = form.makeProfile() else { return }
        var edited = pet
        edited.name = form.trimmedName
        edited.breed = form.trimmedBreed
        edited.profilePhoto = photo
        edited.profile = profile
        onApprove(edited)
        dismiss()
    }
}

/// 반려할 때 사유를 적는 창 (사유가 있어야 반려할 수 있어요)
private struct RejectReasonSheet: View {
    let petName: String
    let onReject: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""

    private var trimmed: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(petName)의 등록을 반려하는 이유를 적어 주세요. 보호자에게 그대로 전달돼요.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.text)
                TextEditor(text: $reason)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(AppTheme.text)
                Spacer()
            }
            .padding(AppTheme.Spacing.large)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("반려 사유")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("반려하기") {
                        onReject(trimmed)
                        dismiss()
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("원장") {
    PetApprovalView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
        .environment(NotificationStore())
}

#Preview("보호자 (접근 불가)") {
    PetApprovalView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(NotificationStore())
}

#Preview("선생님 (다크)") {
    PetApprovalView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(NotificationStore())
        .preferredColorScheme(.dark)
}
