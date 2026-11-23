import SwiftUI

/// 원장 전용: 선생님 초대 코드 만들기, 직원 목록, 퇴사 처리
struct StaffManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(AccountStore.self) private var accounts
    @State private var resigningUser: User?

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canManageStaff(user),
                   let kindergartenID = user.kindergartenID {
                    content(user, kindergartenID: kindergartenID)
                } else {
                    Text("원장님만 볼 수 있어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background.ignoresSafeArea())
                }
            }
            .navigationTitle("직원 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }

    private func content(_ user: User, kindergartenID: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                sectionTitle("선생님 초대 코드")
                Text("선생님이 회원가입할 때 이 코드를 입력해야 해요. 코드는 한 번만 쓸 수 있어요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                Button("새 초대 코드 만들기") {
                    accounts.createInvite(kindergartenID: kindergartenID, createdBy: user.id)
                }
                .buttonStyle(GradientButtonStyle())
                ForEach(accounts.invites) { invite in inviteRow(invite) }

                sectionTitle("직원 \(accounts.staff.count)")
                if accounts.staff.isEmpty {
                    Text("아직 가입한 선생님이 없어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                }
                ForEach(accounts.staff) { teacher in staffRow(teacher) }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear { accounts.reloadStaff(kindergartenID: kindergartenID) }
        .confirmationDialog(
            "퇴사 처리할까요?",
            isPresented: Binding(get: { resigningUser != nil }, set: { if !$0 { resigningUser = nil } }),
            titleVisibility: .visible,
            presenting: resigningUser
        ) { teacher in
            Button("퇴사 처리", role: .destructive) {
                accounts.resign(userID: teacher.id, kindergartenID: kindergartenID)
            }
        } message: { teacher in
            Text("\(teacher.name) 선생님은 더 이상 로그인해서 유치원 정보를 볼 수 없어요.")
        }
    }

    private func inviteRow(_ invite: StaffInvite) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.code)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(invite.isUsed ? AppTheme.subText : AppTheme.text)
                Text(inviteStatusText(invite))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(invite.isUsed ? AppTheme.subText : AppTheme.statusApproved)
            }
            Spacer()
            if !invite.isUsed {
                ShareLink(item: String(localized: "댕답개 배우개 선생님 초대 코드: \(invite.code)")) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("초대 코드 공유")
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func staffRow(_ teacher: User) -> some View {
        HStack {
            Text(teacher.name)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            AccountStatusBadge(status: teacher.status)
            Spacer()
            if teacher.status == .active {
                Button("퇴사 처리") { resigningUser = teacher }
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.statusRejected)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    /// 초대 코드 상태 글자 (사용됨 · 이름 / 사용 가능)
    private func inviteStatusText(_ invite: StaffInvite) -> String {
        guard invite.isUsed else { return String(localized: "사용 가능") }
        let usedName = accounts.staff.first { $0.id == invite.usedByID }?.name ?? String(localized: "선생님")
        return String(localized: "사용됨 · \(usedName)")
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.text)
    }
}

#Preview("원장") {
    StaffManagementView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(AccountStore())
}

#Preview("선생님 (접근 불가, 다크)") {
    StaffManagementView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(AccountStore())
        .preferredColorScheme(.dark)
}
