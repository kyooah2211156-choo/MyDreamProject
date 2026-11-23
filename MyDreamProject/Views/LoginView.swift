import SwiftUI

/// 로그인 화면 (지금은 연습용 가짜 로그인)
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var id = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var infoMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.large) {
                header
                formCard
                #if DEBUG
                sampleAccounts
                #endif
                signUpLink
            }
            .padding(.bottom, AppTheme.Spacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingSignUp) {
            SignUpView { registeredID, message in
                // 가입이 끝나면 바로 들어가지 않고, 아이디를 채워 둔 채 로그인하게 합니다.
                id = registeredID
                password = ""
                session.errorMessage = nil
                infoMessage = message
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("🌳")
                .font(.system(size: 64))
                .accessibilityHidden(true)
            Text("댕답개 배우개")
                .font(AppTheme.Typography.largeTitle)
            Text("반려견 맞춤형 훈련소 & 유치원")
                .font(AppTheme.Typography.caption)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.bottom, 40)
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: AppTheme.Radius.hero,
                                   bottomTrailingRadius: AppTheme.Radius.hero)
                .fill(AppTheme.hero)
                .ignoresSafeArea(edges: .top)
        }
    }

    private var formCard: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            TextField("아이디", text: $id)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .padding(14)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))

            SecureField("비밀번호", text: $password)
                .submitLabel(.go)
                .onSubmit(submit)
                .padding(14)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))

            if let infoMessage {
                Text(infoMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.statusApproved)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let message = session.errorMessage {
                Text(message)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.statusRejected)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: submit) {
                if session.isLoading {
                    ProgressView().tint(AppTheme.buttonText)
                } else {
                    Text("로그인")
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(session.isLoading)
        }
        .foregroundStyle(AppTheme.text)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 12, y: 6)
        .padding(.horizontal, AppTheme.Spacing.large)
    }

    #if DEBUG
    /// 개발 중에만 보이는 연습용 샘플 계정 버튼 (앱스토어·테스트플라이트로 배포하는 버전에서는 자동으로 빠져요)
    private var sampleAccounts: some View {
        VStack(spacing: 8) {
            Text("연습용 샘플 계정 (누르면 자동으로 입력돼요)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
            HStack(spacing: 10) {
                sampleButton("원장", id: "owner")
                sampleButton("선생님", id: "teacher")
                sampleButton("보호자", id: "parent")
                sampleButton("운영자", id: "admin")
            }
            .padding(.horizontal, AppTheme.Spacing.large)
        }
    }

    private func sampleButton(_ title: String, id sampleID: String) -> some View {
        Button(title) {
            id = sampleID
            password = "1234"
        }
        .buttonStyle(SoftButtonStyle())
    }
    #endif

    private var signUpLink: some View {
        Button("회원가입 (원장 · 선생님 · 보호자)") { showingSignUp = true }
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.softButtonText)
            .frame(minHeight: 44)
    }

    private func submit() {
        infoMessage = nil
        Task { await session.login(id: id, password: password) }
    }
}

#Preview("라이트") {
    LoginView()
        .environment(SessionStore())
        .environment(NotebookStore())
}

#Preview("다크") {
    LoginView()
        .environment(SessionStore())
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
