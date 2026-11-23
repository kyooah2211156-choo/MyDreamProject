import SwiftUI

/// 서비스 운영자 화면: 원장 가입 신청을 승인하거나 반려합니다.
struct OwnerApprovalView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AccountStore.self) private var accounts
    @State private var rejectingOwner: User?

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canApproveOwners(user) {
                    content
                } else {
                    Text("서비스 운영자만 볼 수 있어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background.ignoresSafeArea())
                }
            }
            .navigationTitle("원장 가입 승인")
        }
    }

    private var content: some View {
        let pending = accounts.owners.filter { $0.status == .pending }
        let done = accounts.owners.filter { $0.status != .pending }
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
                ForEach(pending) { owner in pendingCard(owner) }

                if !done.isEmpty {
                    sectionTitle("처리 완료")
                    ForEach(done) { owner in
                        HStack {
                            Text(owner.name)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            AccountStatusBadge(status: owner.status)
                        }
                        .padding(14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear { accounts.reloadOwners() }
        .confirmationDialog(
            "가입을 반려할까요?",
            isPresented: Binding(get: { rejectingOwner != nil }, set: { if !$0 { rejectingOwner = nil } }),
            titleVisibility: .visible,
            presenting: rejectingOwner
        ) { owner in
            Button("반려", role: .destructive) { accounts.rejectOwner(id: owner.id) }
        } message: { owner in
            Text("\(owner.name)님은 로그인할 수 없게 돼요.")
        }
    }

    private func pendingCard(_ owner: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(owner.name)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                AccountStatusBadge(status: owner.status)
            }
            Text("새 유치원 원장으로 가입을 신청했어요. 승인하면 바로 로그인해서 쓸 수 있어요.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
            HStack(spacing: 10) {
                Button("반려") { rejectingOwner = owner }
                    .buttonStyle(SoftButtonStyle())
                Button("승인") { accounts.approveOwner(id: owner.id) }
                    .buttonStyle(GradientButtonStyle())
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.text)
    }
}

/// 계정 상태 배지 (승인 대기 주황 / 이용 중 초록 / 반려·퇴사 빨강)
struct AccountStatusBadge: View {
    let status: AccountStatus

    private var color: Color {
        switch status {
        case .pending: AppTheme.statusPending
        case .active: AppTheme.statusApproved
        case .rejected, .resigned, .suspended: AppTheme.statusRejected
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

#Preview("운영자") {
    OwnerApprovalView()
        .environment(SessionStore(currentUser: SampleData.admin))
        .environment(AccountStore())
}

#Preview("원장 (접근 불가, 다크)") {
    OwnerApprovalView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(AccountStore())
        .preferredColorScheme(.dark)
}
