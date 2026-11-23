import SwiftUI

/// 유치원 철학과 운영규칙을 다시 읽어 볼 수 있는 창. 보호자에게는 내 경고 횟수도 보여줘요.
struct PolicySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(AccountStore.self) private var accounts

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if let user = session.currentUser, user.role == .parent {
                        warningCard(user)
                    }
                    KindergartenPolicyView()
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("유치원 철학 · 운영규칙")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .onAppear { accounts.reloadParents() }
        }
    }

    /// 내가 받은 경고 횟수 (● 찬 점이 받은 경고)
    private func warningCard(_ user: User) -> some View {
        let count = accounts.parent(id: user.id)?.warningCount ?? 0
        let limit = KindergartenPolicy.warningLimit
        return HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(count == 0 ? AppTheme.statusApproved : AppTheme.statusPending)
            VStack(alignment: .leading, spacing: 4) {
                Text("내 경고 \(count) / \(limit)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                HStack(spacing: 6) {
                    ForEach(0..<limit, id: \.self) { index in
                        Circle()
                            .fill(index < count ? AppTheme.statusRejected : AppTheme.track)
                            .frame(width: 12, height: 12)
                    }
                }
                Text(count == 0 ? "받은 경고가 없어요" : "경고는 원장님이 직접 기록해요")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("보호자") {
    PolicySheetView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(AccountStore())
}

#Preview("선생님 (다크)") {
    PolicySheetView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(AccountStore())
        .preferredColorScheme(.dark)
}
