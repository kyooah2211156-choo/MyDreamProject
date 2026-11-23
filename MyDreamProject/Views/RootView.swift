import SwiftUI

/// 앱의 첫 관문: 로그인 전에는 로그인 화면, 로그인 후에는 역할에 맞는 화면
struct RootView: View {
    @Environment(SessionStore.self) private var session
    /// 알림장·사진첩·반려견 데이터. 로그아웃했다 다시 들어와도 같은 데이터를 봅니다.
    @State private var notebookStore = NotebookStore()
    /// 앱 안 알림 데이터
    @State private var notificationStore = NotificationStore()

    var body: some View {
        if let user = session.currentUser {
            SignedInView(user: user)
                .id(user.id)
                .environment(notebookStore)
                .environment(notificationStore)
        } else {
            LoginView()
                .environment(notebookStore)
        }
    }
}

/// 로그인 후 화면: 홈 / 훈련 / 알림장 / 사진첩 탭 (원장·선생님은 승인 탭 추가)
private struct SignedInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @State private var showingNotifications = false
    let user: User

    var body: some View {
        VStack(spacing: 0) {
            userBar
            TabView {
                home
                    .tabItem { Label("홈", systemImage: "house.fill") }
                TrainingListView()
                    .tabItem { Label("훈련", systemImage: "figure.walk") }
                NotebookListView()
                    .tabItem { Label("알림장", systemImage: "book.closed.fill") }
                AlbumView()
                    .tabItem { Label("사진첩", systemImage: "photo.on.rectangle.angled") }
                if Permissions.canReviewPets(user) {
                    PetApprovalView()
                        .tabItem { Label("승인", systemImage: "checkmark.seal.fill") }
                        .badge(store.pendingPets.count)
                }
            }
            .tint(AppTheme.softButtonText)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showingNotifications) { NotificationListView() }
    }

    private var userBar: some View {
        HStack {
            Text("\(user.name) · \(user.role.displayName)")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            Spacer()
            notificationButton
            Button("로그아웃") { session.logout() }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.softButtonText)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, AppTheme.Spacing.screen)
        .background(AppTheme.card)
    }

    /// 종 모양 버튼. 안 읽은 알림 개수가 빨간 배지로 보여요.
    private var notificationButton: some View {
        let unread = notifications.unreadCount(for: user)
        return Button {
            showingNotifications = true
        } label: {
            Image(systemName: "bell.fill")
                .foregroundStyle(AppTheme.softButtonText)
                .frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(AppTheme.statusRejected, in: Capsule())
                            .offset(x: -2, y: 4)
                    }
                }
        }
        .accessibilityLabel(unread > 0 ? "알림 \(unread)개 안 읽음" : "알림")
    }

    @ViewBuilder
    private var home: some View {
        switch user.role {
        case .owner:
            TeacherHomeView(viewModel: .live, canEditKindergartenName: true)
        case .teacher:
            TeacherHomeView(viewModel: .live, canEditKindergartenName: false)
        case .parent:
            ParentHomeView()
        }
    }
}

#Preview("로그인 전") {
    RootView().environment(SessionStore())
}

#Preview("원장") {
    RootView().environment(SessionStore(currentUser: SampleData.owner))
}

#Preview("선생님") {
    RootView().environment(SessionStore(currentUser: SampleData.teacher))
}

#Preview("보호자 (다크)") {
    RootView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .preferredColorScheme(.dark)
}
