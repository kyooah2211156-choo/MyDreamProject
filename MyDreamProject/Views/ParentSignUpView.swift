import SwiftUI

/// 보호자 가입 화면: 보호자 정보와 반려견 정보를 함께 적습니다. (모두 필수)
struct ParentSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store

    @State private var parentName = ""
    @State private var userID = ""
    @State private var password = ""
    @State private var form = PetFormState()
    @State private var showErrors = false

    private func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 보호자 정보 중 비어 있는 항목
    private var missingAccount: [String] {
        var missing: [String] = []
        if clean(parentName).isEmpty { missing.append("보호자 이름") }
        if clean(userID).isEmpty { missing.append("아이디") }
        if password.isEmpty { missing.append("비밀번호") }
        return missing
    }

    private var allMissing: [String] { missingAccount + form.missingFields.map(\.rawValue) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Text("보호자 정보")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.text)
                    accountCard

                    Text("반려견 정보")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.text)
                    Text("모든 항목은 필수예요. 원장님·선생님이 확인하면 알림장과 사진을 볼 수 있어요.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                    PetRegistrationFormView(form: $form, showErrors: showErrors)

                    if showErrors && !allMissing.isEmpty {
                        Text("빠진 항목: " + allMissing.joined(separator: ", "))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.statusRejected)
                    }
                    if let message = session.errorMessage {
                        Text(message)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.statusRejected)
                    }

                    Button(action: submit) {
                        if session.isLoading {
                            ProgressView().tint(AppTheme.buttonText)
                        } else {
                            Text("가입하고 승인 요청하기")
                        }
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(session.isLoading)
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("보호자 가입")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .onAppear { session.errorMessage = nil }
        }
    }

    private var accountCard: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            TextField("보호자 이름 *", text: $parentName)
                .textContentType(.name)
                .padding(12)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            TextField("아이디 *", text: $userID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            SecureField("비밀번호 * (4자 이상)", text: $password)
                .padding(12)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(AppTheme.text)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func submit() {
        showErrors = true
        guard allMissing.isEmpty, let profile = form.makeProfile() else { return }
        Task {
            // 1) 계정 만들기  2) 반려견을 '대기중'으로 등록  3) 로그인
            guard let user = await session.register(name: parentName, id: userID, password: password) else { return }
            store.register(user: user)
            store.addPet(Pet(
                id: UUID().uuidString,
                name: form.trimmedName,
                breed: form.trimmedBreed,
                profilePhoto: nil,
                ownerID: user.id,
                status: .pending,
                rejectionReason: nil,
                requesterID: user.id,
                reviewerID: nil,
                profile: profile
            ))
            await session.login(id: userID, password: password)
        }
    }
}

#Preview("보호자 가입") {
    ParentSignUpView()
        .environment(SessionStore())
        .environment(NotebookStore())
}

#Preview("보호자 가입 (다크)") {
    ParentSignUpView()
        .environment(SessionStore())
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
