import SwiftUI
import PhotosUI

enum PetRequestMode: Identifiable {
    case new
    case resubmit(Pet)

    var id: String {
        switch self {
        case .new: "new"
        case .resubmit(let pet): "resubmit-\(pet.id)"
        }
    }
}

/// 반려견 등록 신청 화면: 새 반려견을 신청하거나, 반려된 반려견을 수정해서 다시 신청합니다.
/// 항목은 가입할 때와 같고 모두 필수예요. (프로필 사진만 선택)
struct PetRequestView: View {
    let mode: PetRequestMode

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(NotificationStore.self) private var notifications

    @State private var form: PetFormState
    @State private var photo: PhotoSource?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showErrors = false

    init(mode: PetRequestMode) {
        self.mode = mode
        if case .resubmit(let pet) = mode {
            _form = State(initialValue: PetFormState(pet: pet))
            _photo = State(initialValue: pet.profilePhoto)
        } else {
            _form = State(initialValue: PetFormState())
            _photo = State(initialValue: nil)
        }
    }

    private var resubmittingPet: Pet? {
        if case .resubmit(let pet) = mode { return pet }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if let reason = resubmittingPet?.rejectionReason {
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

                    Text("원장님·선생님이 확인하면 승인돼요. 승인되기 전에는 알림장과 사진을 볼 수 없어요.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)

                    if showErrors && !form.missingFields.isEmpty {
                        Text("빠진 항목: \(form.missingFields.map(\.title).joined(separator: ", "))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.statusRejected)
                    }

                    Button(action: submit) {
                        Text(resubmittingPet == nil ? "신청하기" : "다시 신청하기")
                    }
                    .buttonStyle(GradientButtonStyle())
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(resubmittingPet == nil ? String(localized: "반려견 등록 신청") : String(localized: "수정해서 다시 신청"))
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

    // MARK: 신청

    private func submit() {
        showErrors = true
        guard let user = session.currentUser, Permissions.canRequestPet(user),
              let profile = form.makeProfile() else { return }

        let petName = form.trimmedName
        if let old = resubmittingPet {
            // 반려됐던 반려견을 고쳐서 '대기중'으로 다시 신청
            var updated = old
            updated.name = petName
            updated.breed = form.trimmedBreed
            updated.profilePhoto = photo
            updated.profile = profile
            notebook.resubmitPet(updated)
        } else {
            notebook.addPet(Pet(
                id: UUID().uuidString,
                name: petName,
                breed: form.trimmedBreed,
                profilePhoto: photo,
                ownerID: user.id,
                status: .pending,
                rejectionReason: nil,
                requesterID: user.id,
                reviewerID: nil,
                profile: profile
            ))
        }
        notifyStaff(requester: user, petName: petName, isResubmit: resubmittingPet != nil)
        dismiss()
    }

    /// 원장·선생님에게 새 신청이 왔다고 알려요.
    private func notifyStaff(requester: User, petName: String, isResubmit: Bool) {
        let title = isResubmit
            ? String(localized: "반려견 등록 재신청")
            : String(localized: "새 반려견 등록 신청")
        let content = isResubmit
            ? String(localized: "\(requester.name)님이 \(petName)의 등록을 다시 신청했어요.")
            : String(localized: "\(requester.name)님이 \(petName)의 등록을 신청했어요.")
        for staff in notebook.users where staff.role == .owner || staff.role == .teacher {
            notifications.send(to: staff.id, title: title, content: content)
        }
    }
}

#Preview("새 신청") {
    PetRequestView(mode: .new)
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(NotificationStore())
}

#Preview("반려됨 → 다시 신청 (다크)") {
    PetRequestView(mode: .resubmit(SampleData.petRejected))
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(NotificationStore())
        .preferredColorScheme(.dark)
}
