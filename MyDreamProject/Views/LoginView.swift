import SwiftUI

/// 로그인 화면 (지금은 연습용 가짜 로그인)
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var id = ""
    @State private var password = ""
    @State private var showingSignUp = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.large) {
                header
                formCard
                sampleAccounts
                signUpLink
            }
            .padding(.bottom, AppTheme.Spacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingSignUp) { ParentSignUpView() }
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

    private var sampleAccounts: some View {
        VStack(spacing: 8) {
            Text("연습용 샘플 계정 (누르면 자동으로 입력돼요)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
            HStack(spacing: 10) {
                sampleButton("원장", id: "owner")
                sampleButton("선생님", id: "teacher")
                sampleButton("보호자", id: "parent")
            }
            .padding(.horizontal, AppTheme.Spacing.large)
        }
    }

    private var signUpLink: some View {
        Button("보호자 가입하기") { showingSignUp = true }
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.softButtonText)
            .frame(minHeight: 44)
    }

    private func sampleButton(_ title: String, id sampleID: String) -> some View {
        Button(title) {
            id = sampleID
            password = "1234"
        }
        .buttonStyle(SoftButtonStyle())
    }

    private func submit() {
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
