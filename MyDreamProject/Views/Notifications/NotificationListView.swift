import SwiftUI

/// 알림 목록: 안 읽은 알림은 굵게 표시되고, 누르면 읽음 처리돼요.
struct NotificationListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotificationStore.self) private var notifications

    var body: some View {
        NavigationStack {
            if let user = session.currentUser {
                content(user)
            }
        }
    }

    private func content(_ user: User) -> some View {
        let items = notifications.notifications(for: user)
        return ScrollView {
            LazyVStack(spacing: 10) {
                if items.isEmpty {
                    Text("새 알림이 없어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
                ForEach(items) { item in row(item) }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("모두 읽음") { notifications.markAllRead(for: user) }
                    .disabled(notifications.unreadCount(for: user) == 0)
            }
        }
    }

    private func row(_ item: AppNotification) -> some View {
        Button {
            notifications.markRead(item.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(item.isRead ? Color.clear : AppTheme.statusRejected)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(item.isRead ? AppTheme.Typography.body : AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(item.content)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subText)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isRead ? item.title : String(localized: "안 읽음. \(item.title)"))
    }
}

#Preview("보호자") {
    NotificationListView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotificationStore())
}

#Preview("원장 (다크)") {
    NotificationListView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotificationStore())
        .preferredColorScheme(.dark)
}
