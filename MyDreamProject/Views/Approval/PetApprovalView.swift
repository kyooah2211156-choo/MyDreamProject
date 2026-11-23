import SwiftUI

/// 반려견 등록 승인 화면 (원장·선생님). 신청 내용을 직접 확인하고 승인하거나 반려합니다.
struct PetApprovalView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @State private var rejectingPet: Pet?

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
        let done = store.pets.filter { $0.status != .pending }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                sectionTitle("승인 대기 \(pending.count)")
                if pending.isEmpty {
                    Text("대기 중인 신청이 없어요 🎉")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                }
                ForEach(pending) { pet in requestCard(pet, user: user) }

                if !done.isEmpty {
                    sectionTitle("처리 완료")
                    ForEach(done) { pet in doneRow(pet) }
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

    private func doneRow(_ pet: Pet) -> some View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.text)
    }

    // MARK: 승인·반려 (처리하면 신청한 보호자에게 앱 안 알림이 갑니다)

    private func approve(_ pet: Pet, by user: User) {
        guard Permissions.canReviewPets(user),
              let updated = store.approvePet(id: pet.id, reviewerID: user.id) else { return }
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
