import SwiftUI

/// 앱의 첫 관문: 로그인 전에는 로그인 화면, 로그인 후에는 역할에 맞는 화면
struct RootView: View {
    @Environment(SessionStore.self) private var session
    /// 알림장·사진첩·반려견 데이터. 로그아웃했다 다시 들어와도 같은 데이터를 봅니다.
    @State private var notebookStore = NotebookStore()
    /// 앱 안 알림 데이터
    @State private var notificationStore = NotificationStore()
    /// 한 달 시간표 데이터
    @State private var scheduleStore = ScheduleStore()
    /// 원장 승인·선생님 초대·직원 관리 데이터
    @State private var accountStore = AccountStore()
    /// 건강 기록(응가·몸무게·식사량) 데이터
    @State private var healthStore = HealthRecordStore()
    /// 강아지별 훈련 진행도 데이터
    @State private var trainingProgressStore = TrainingProgressStore()
    /// 보호자 경고 이력 (사유·직원·시각)
    @State private var warningLogStore = WarningLogStore()
    /// 날짜별 등원·하원 기록 (월별 출석, 개인 기록, 이용권 차감)
    @State private var attendanceStore = AttendanceStore()
    /// 이용권·결제 내역 (테스트용)
    @State private var billingStore = BillingStore()
    /// 신규 원생 입학 절차 (증명서·확인·체험 평가·최종 승인)
    @State private var admissionStore = AdmissionStore()
    /// 유치원 이용·상담·픽업 예약과 비공개 1:1 상담
    @State private var reservationStore = ReservationStore()
    /// 반려견 상세 정보와 맞춤 훈련 계획
    @State private var petDetailStore = PetDetailStore()

    var body: some View {
        if let user = session.currentUser {
            SignedInView(user: user)
                .id(user.id)
                .environment(notebookStore)
                .environment(notificationStore)
                .environment(scheduleStore)
                .environment(accountStore)
                .environment(healthStore)
                .environment(trainingProgressStore)
                .environment(warningLogStore)
                .environment(attendanceStore)
                .environment(billingStore)
                .environment(admissionStore)
                .environment(reservationStore)
                .environment(petDetailStore)
        } else {
            LoginView()
                .environment(notebookStore)
        }
    }
}

/// 종 버튼, 달력 버튼, 직원 버튼으로 여는 창 종류
private enum SignedInSheet: String, Identifiable {
    case notifications
    case schedule
    case staff
    case settings

    var id: String { rawValue }
}

/// 로그인 후 화면
/// - 운영자: 원장 가입 승인 화면만 보입니다. (유치원 안의 정보는 볼 수 없어요)
/// - 그 외: 홈 / 훈련 / 알림장 / 사진첩 탭 (원장·선생님은 승인 탭 추가)
private struct SignedInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @Environment(AttendanceStore.self) private var attendanceStore
    @Environment(BillingStore.self) private var billing
    @Environment(AppSettingsStore.self) private var appSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeSheet: SignedInSheet?
    /// 오늘 등원 상태. 홈·알림장 작성·건강 기록·훈련 화면이 함께 씁니다.
    @State private var attendance = TeacherHomeViewModel.live
    let user: User

    var body: some View {
        VStack(spacing: 0) {
            userBar
            if user.role == .admin {
                OwnerApprovalView()
            } else {
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
        }
        .background(AppTheme.background.ignoresSafeArea())
        // 퇴사 처리나 이용 중단이 되면 몇 초 안에 바로 로그아웃됩니다.
        .task(id: user.id) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                session.validateSession()
            }
        }
        // 날짜가 바뀌면 어제 등원 상태를 비우고 모두 '등원 대기'로 시작합니다.
        .onAppear {
            attendance.startNewDayIfNeeded()
            connectAttendance()
            connectDevicePush()
        }
        .onDisappear { notifications.onSend = nil }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.validateSession()
                attendance.startNewDayIfNeeded()
                Task { await appSettings.syncPushWithSystem() }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .notifications: NotificationListView()
            case .schedule: ScheduleView()
            case .staff: StaffManagementView()
            case .settings: SettingsView()
            }
        }
        .environment(attendance)
    }

    /// 등원·하원을 누르면 출석 기록을 남기고, 이용권을 한 번 차감하고, 보호자에게 앱 안 알림을 보냅니다.
    private func connectAttendance() {
        attendance.onCheckIn = { dog in
            guard let petID = dog.petID else { return }
            let isUndo = attendanceStore.entry(petID: petID, on: .now)?.checkOut != nil   // 하원을 되돌린 경우
            attendanceStore.recordCheckIn(petID: petID)
            guard !isUndo else { return }
            let usedPass = billing.consume(petID: petID)
            guard let ownerID = store.pets.first(where: { $0.id == petID })?.ownerID else { return }
            var content = String(localized: "\(dog.name)가 \(Date.now.formatted(date: .omitted, time: .shortened))에 등원했어요.")
            if let usedPass {
                content += " " + String(localized: "이용권 \(usedPass.remainingCount)회 남았어요.")
            }
            notifications.send(to: ownerID, title: String(localized: "등원 알림"), content: content)
        }
        attendance.onCheckOut = { dog in
            guard let petID = dog.petID else { return }
            attendanceStore.recordCheckOut(petID: petID)
            guard let ownerID = store.pets.first(where: { $0.id == petID })?.ownerID else { return }
            notifications.send(to: ownerID, title: String(localized: "하원 알림"),
                               content: String(localized: "\(dog.name)가 \(Date.now.formatted(date: .omitted, time: .shortened))에 하원했어요."))
        }
    }

    /// 내 앞으로 온 앱 안 알림이 생기면, 기기 알림이 켜져 있을 때 배너도 함께 띄웁니다.
    private func connectDevicePush() {
        let myID = user.id
        notifications.onSend = { [appSettings] notification in
            guard notification.recipientID == myID, appSettings.pushEnabled else { return }
            DevicePushService.shared.deliver(title: notification.title, body: notification.content)
        }
    }

    private var userBar: some View {
        HStack(spacing: 0) {
            Text("\(user.name) · \(user.role.displayName)")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            if Permissions.canManageStaff(user) {
                iconButton("person.2.fill", label: "직원 관리") { activeSheet = .staff }
            }
            if user.role != .admin {
                iconButton("calendar", label: "한 달 시간표") { activeSheet = .schedule }
                notificationButton
            }
            iconButton("gearshape.fill", label: "설정") { activeSheet = .settings }
            Button("로그아웃") { session.logout() }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.softButtonText)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, AppTheme.Spacing.screen)
        .background(AppTheme.card)
    }

    private func iconButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.softButtonText)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }

    /// 종 모양 버튼. 안 읽은 알림 개수가 빨간 배지로 보여요.
    private var notificationButton: some View {
        let unread = notifications.unreadCount(for: user)
        return Button {
            activeSheet = .notifications
        } label: {
            Image(systemName: "bell.fill")
                .foregroundStyle(AppTheme.softButtonText)
                .frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    if unread > 0 {
                        Text("\(unread)")
                            .font(AppTheme.Typography.caption2Bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(AppTheme.statusRejected, in: Capsule())
                            .offset(x: -2, y: 4)
                    }
                }
        }
        .accessibilityLabel(unread > 0 ? String(localized: "알림 \(unread)개 안 읽음") : String(localized: "알림"))
    }

    @ViewBuilder
    private var home: some View {
        switch user.role {
        case .owner:
            TeacherHomeView(viewModel: attendance, canEditKindergartenName: true, canManageWarnings: true,
                            showsHealthRecords: true, pets: store.pets.filter(\.isApproved))
        case .teacher:
            TeacherHomeView(viewModel: attendance, canEditKindergartenName: false, canManageWarnings: true,
                            showsHealthRecords: true,
                            pets: store.pets.filter(\.isApproved))
        case .parent:
            ParentHomeView()
        case .admin:
            EmptyView()
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

#Preview("운영자") {
    RootView().environment(SessionStore(currentUser: SampleData.admin))
}

#Preview("보호자 (다크)") {
    RootView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .preferredColorScheme(.dark)
}
