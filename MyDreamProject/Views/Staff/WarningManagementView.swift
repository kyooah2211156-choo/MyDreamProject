import SwiftUI

/// 원장 전용: 보호자에게 운영규칙 경고를 직접 세어 기록합니다. 경고 3회가 되면 이용이 중단돼요.
struct WarningManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(AccountStore.self) private var accounts
    @Environment(NotebookStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @State private var warningTarget: User?

    private let limit = KindergartenPolicy.warningLimit

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canManageStaff(user) {
                    content
                } else {
                    Text("원장님만 볼 수 있어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background.ignoresSafeArea())
                }
            }
            .navigationTitle("보호자 경고 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("운영규칙을 어긴 보호자에게 경고를 기록해요. 경고가 \(limit)회가 되면 이용이 바로 중단돼요. 잘못 기록했다면 경고를 하나 줄이면 돼요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                if accounts.parents.isEmpty {
                    Text("가입한 보호자가 없어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
                ForEach(accounts.parents) { parent in parentCard(parent) }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear { accounts.reloadParents() }
        .confirmationDialog(
            "경고를 기록할까요?",
            isPresented: Binding(get: { warningTarget != nil }, set: { if !$0 { warningTarget = nil } }),
            titleVisibility: .visible,
            presenting: warningTarget
        ) { parent in
            Button("경고 기록", role: .destructive) { addWarning(parent) }
        } message: { parent in
            Text(parent.warningCount + 1 >= limit
                 ? String(localized: "\(parent.name)님은 경고 \(limit)회가 되어 이용이 바로 중단돼요.")
                 : String(localized: "\(parent.name)님의 경고가 \(parent.warningCount + 1)회가 돼요."))
        }
    }

    private func parentCard(_ parent: User) -> some View {
        let petNames = store.pets.filter { $0.ownerID == parent.id }.map(\.name)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(parent.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                AccountStatusBadge(status: parent.status)
                Spacer()
            }
            if !petNames.isEmpty {
                Text("반려견 \(petNames.joined(separator: ", "))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            HStack(spacing: 6) {
                ForEach(0..<limit, id: \.self) { index in
                    Circle()
                        .fill(index < parent.warningCount ? AppTheme.statusRejected : AppTheme.track)
                        .frame(width: 14, height: 14)
                }
                Text("경고 \(parent.warningCount) / \(limit)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                    .padding(.leading, 4)
            }
            HStack(spacing: 10) {
                Button("경고 −1") { removeWarning(parent) }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(parent.warningCount == 0)
                Button("경고 +1") { warningTarget = parent }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(parent.status == .suspended)
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    // MARK: 경고 기록 (바뀐 보호자에게 앱 안 알림이 갑니다)

    private func addWarning(_ parent: User) {
        guard let owner = session.currentUser, Permissions.canManageStaff(owner) else { return }
        accounts.addWarning(userID: parent.id)
        guard let updated = accounts.parent(id: parent.id) else { return }
        if updated.status == .suspended {
            notifications.send(to: parent.id, title: String(localized: "이용이 중단됐어요"),
                               content: String(localized: "운영규칙 경고가 \(limit)회 쌓여 이용이 중단됐어요. 원장님께 문의해 주세요."))
        } else if updated.warningCount == limit - 1 {
            // 앱 안에서 읽을 수 있는 마지막 알림이라, 다음 경고에 이용이 중단된다고 분명히 알려요.
            notifications.send(to: parent.id, title: String(localized: "마지막 경고예요 (\(updated.warningCount)/\(limit))"),
                               content: String(localized: "경고가 \(updated.warningCount)회 기록됐어요. 한 번 더 기록되면 이용이 중단돼요."))
        } else {
            notifications.send(to: parent.id, title: String(localized: "운영규칙 경고 \(updated.warningCount)/\(limit)"),
                               content: String(localized: "경고가 \(updated.warningCount)회 기록됐어요. \(limit)회가 되면 이용이 중단돼요."))
        }
    }

    private func removeWarning(_ parent: User) {
        guard let owner = session.currentUser, Permissions.canManageStaff(owner) else { return }
        accounts.removeWarning(userID: parent.id)
    }
}

#Preview("원장") {
    WarningManagementView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(AccountStore())
        .environment(NotebookStore())
        .environment(NotificationStore())
}

#Preview("선생님 (접근 불가, 다크)") {
    WarningManagementView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(AccountStore())
        .environment(NotebookStore())
        .environment(NotificationStore())
        .preferredColorScheme(.dark)
}
