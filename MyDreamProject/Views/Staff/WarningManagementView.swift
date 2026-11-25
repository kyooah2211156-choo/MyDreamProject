import SwiftUI

/// 원장 전용: 보호자에게 운영규칙 경고를 직접 세어 기록합니다. 경고 3회가 되면 이용이 중단돼요.
struct WarningManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(AccountStore.self) private var accounts
    @Environment(NotebookStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @Environment(WarningLogStore.self) private var warningLog
    @State private var action: WarningAction?
    @State private var expandedParentIDs: Set<String> = []

    private let limit = KindergartenPolicy.warningLimit

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canIssueWarning(user) {
                    content
                } else {
                    Text("원장님과 선생님만 볼 수 있어요")
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
                Text("운영규칙을 어긴 보호자에게 사유와 함께 경고를 기록해요. 경고가 \(limit)회가 되면 이용이 바로 중단돼요. 경고 정정과 이용 재개는 원장님이 확인한 뒤에만 할 수 있어요.")
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
        .sheet(item: $action) { action in
            WarningActionSheet(action: action, limit: limit) { reason in
                perform(action, reason: reason)
            }
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
            if parent.status == .suspended, let record = warningLog.suspensionRecord(for: parent.id) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("이용 중단 사유")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.statusRejected)
                    Text(record.reason)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.text)
                    Text("\(record.date.formatted(date: .abbreviated, time: .shortened)) · 처리 \(store.authorName(record.staffID))")
                        .font(AppTheme.Typography.caption2)
                        .foregroundStyle(AppTheme.subText)
                }
            }
            HStack(spacing: 10) {
                if canCorrect {
                    Button("경고 −1") { action = .remove(parent) }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(parent.warningCount == 0)
                }
                Button("경고 +1") { action = .add(parent) }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(parent.status == .suspended)
            }
            if canCorrect && parent.status == .suspended {
                Button("원장 확인 후 이용 재개") { action = .resume(parent) }
                    .buttonStyle(SoftButtonStyle())
            }
            historySection(parent)
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    private var canCorrect: Bool {
        session.currentUser.map(Permissions.canCorrectWarning) ?? false
    }

    /// 이 보호자의 경고 이력 (누르면 펼쳐져요)
    @ViewBuilder
    private func historySection(_ parent: User) -> some View {
        let history = warningLog.history(for: parent.id)
        let isOpen = expandedParentIDs.contains(parent.id)
        Button {
            if isOpen { expandedParentIDs.remove(parent.id) } else { expandedParentIDs.insert(parent.id) }
        } label: {
            HStack(spacing: 6) {
                Text("경고 이력 \(history.count)건")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.softButtonText)
                Image(systemName: "chevron.down")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if isOpen {
            if history.isEmpty {
                Text("아직 이력이 없어요")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            ForEach(history) { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(record.kind.displayName) · 경고 \(record.countAfter)/\(limit)")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(record.kind == .removed || record.kind == .resumed ? AppTheme.statusApproved : AppTheme.statusRejected)
                    Text(record.reason)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.text)
                    Text("\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(store.authorName(record.staffID))")
                        .font(AppTheme.Typography.caption2)
                        .foregroundStyle(AppTheme.subText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 사유를 확인한 뒤 실제로 처리합니다. 처리한 직원과 시각은 자동으로 남아요.
    private func perform(_ action: WarningAction, reason: String) {
        guard let staff = session.currentUser, Permissions.canIssueWarning(staff) else { return }
        switch action {
        case .add(let parent):
            addWarning(parent, reason: reason, by: staff)
        case .remove(let parent):
            guard Permissions.canCorrectWarning(staff), parent.warningCount > 0 else { return }
            accounts.removeWarning(userID: parent.id)
            logResult(.removed, parent: parent, reason: reason, staff: staff)
        case .resume(let parent):
            guard Permissions.canCorrectWarning(staff), parent.status == .suspended else { return }
            accounts.removeWarning(userID: parent.id)   // 경고를 하나 줄이면 3회 미만이 되어 이용이 다시 열려요.
            logResult(.resumed, parent: parent, reason: reason, staff: staff)
            notifications.send(to: parent.id, title: String(localized: "이용이 재개됐어요"),
                               content: String(localized: "원장님이 확인해 이용이 다시 열렸어요."))
        }
    }

    private func logResult(_ kind: WarningEventKind, parent: User, reason: String, staff: User) {
        let count = accounts.parent(id: parent.id)?.warningCount ?? 0
        warningLog.log(kind, parentID: parent.id, reason: reason, staffID: staff.id, countAfter: count)
    }

    // MARK: 경고 기록 (바뀐 보호자에게 앱 안 알림이 갑니다)

    private func addWarning(_ parent: User, reason: String, by staff: User) {
        accounts.addWarning(userID: parent.id)
        guard let updated = accounts.parent(id: parent.id) else { return }
        warningLog.log(.added, parentID: parent.id, reason: reason, staffID: staff.id, countAfter: updated.warningCount)
        if updated.status == .suspended {
            warningLog.log(.suspended, parentID: parent.id,
                           reason: String(localized: "경고 \(limit)회 누적 · 마지막 사유: \(reason)"),
                           staffID: staff.id, countAfter: updated.warningCount)
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
}

/// 경고를 처리하기 전에 사유를 적고 한 번 더 확인하는 창
enum WarningAction: Identifiable {
    case add(User)
    case remove(User)
    case resume(User)

    var id: String {
        switch self {
        case .add(let user): "add-\(user.id)"
        case .remove(let user): "remove-\(user.id)"
        case .resume(let user): "resume-\(user.id)"
        }
    }
}

private struct WarningActionSheet: View {
    let action: WarningAction
    let limit: Int
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @State private var reason = ""
    @State private var confirming = false

    private var trimmed: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var parent: User {
        switch action {
        case .add(let user), .remove(let user), .resume(let user): user
        }
    }

    private var title: String {
        switch action {
        case .add: String(localized: "경고 기록")
        case .remove: String(localized: "경고 차감")
        case .resume: String(localized: "이용 재개")
        }
    }

    private var consequence: String {
        switch action {
        case .add:
            parent.warningCount + 1 >= limit
                ? String(localized: "\(parent.name)님은 경고 \(limit)회가 되어 이용이 바로 중단돼요.")
                : String(localized: "\(parent.name)님의 경고가 \(parent.warningCount + 1)회가 돼요.")
        case .remove:
            String(localized: "\(parent.name)님의 경고가 \(max(parent.warningCount - 1, 0))회로 줄어요.")
        case .resume:
            String(localized: "\(parent.name)님의 경고를 하나 줄이고 이용을 다시 열어요.")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(consequence)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                Text("사유를 적어 주세요. 처리한 직원(\(session.currentUser?.name ?? ""))과 날짜·시간은 자동으로 남아요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                TextEditor(text: $reason)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(AppTheme.text)
                Button(title) { confirming = true }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(trimmed.isEmpty)
                Spacer()
            }
            .padding(AppTheme.Spacing.large)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            }
            .confirmationDialog("\(title)을(를) 진행할까요?", isPresented: $confirming, titleVisibility: .visible) {
                Button(title, role: .destructive) {
                    onConfirm(trimmed)
                    dismiss()
                }
            } message: {
                Text(consequence)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("원장") {
    WarningManagementView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(AccountStore())
        .environment(NotebookStore())
        .environment(NotificationStore())
        .environment(WarningLogStore())
}

#Preview("선생님 (기록만 가능, 다크)") {
    WarningManagementView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(AccountStore())
        .environment(NotebookStore())
        .environment(NotificationStore())
        .environment(WarningLogStore())
        .preferredColorScheme(.dark)
}
