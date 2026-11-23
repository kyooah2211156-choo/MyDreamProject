import SwiftUI

/// 회원가입 화면: 원장 / 선생님 / 보호자 중 하나를 골라 가입합니다.
/// 보호자는 반려견 정보도 함께 적어요. (모두 필수)
/// - 원장: 가입하면 '승인 대기'가 되고, 서비스 운영자가 승인해야 로그인할 수 있어요.
/// - 선생님: 원장이 준 초대 코드가 있어야 가입할 수 있어요.
/// - 보호자: 바로 가입돼요.
/// 가입이 끝나면 자동으로 로그인하지 않고, 로그인 화면에서 아이디와 비밀번호를 입력해 들어갑니다.
struct SignUpView: View {
    /// 가입이 끝났을 때 알려 줍니다. (가입한 아이디, 로그인 화면에 보여줄 안내 문구)
    let onCompleted: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var store

    @State private var role: Role
    @State private var name = ""
    @State private var userID = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var inviteCode = ""
    @State private var agreedToPolicy = false
    @State private var form = PetFormState()
    @State private var showErrors = false

    init(initialRole: Role = .parent, onCompleted: @escaping (String, String) -> Void) {
        _role = State(initialValue: initialRole)
        self.onCompleted = onCompleted
    }

    private func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameLabel: String { role == .parent ? "보호자 이름" : "이름" }

    /// 계정 정보 중 비어 있거나 맞지 않는 항목
    private var missingAccount: [String] {
        var missing: [String] = []
        if clean(name).isEmpty { missing.append(nameLabel) }
        if clean(userID).isEmpty { missing.append("아이디") }
        if password.isEmpty { missing.append("비밀번호") }
        if passwordConfirm.isEmpty || passwordConfirm != password { missing.append("비밀번호 확인(같아야 해요)") }
        if role == .teacher && clean(inviteCode).isEmpty { missing.append("초대 코드") }
        return missing
    }

    private var allMissing: [String] {
        missingAccount
            + (role == .parent ? form.missingFields.map(\.rawValue) : [])
            + (role == .parent && !agreedToPolicy ? ["운영규칙 동의"] : [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Picker("가입 유형", selection: $role) {
                        ForEach([Role.owner, .teacher, .parent], id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("\(role.displayName) 정보")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.text)
                    accountCard

                    if role == .parent {
                        Text("반려견 정보")
                            .font(AppTheme.Typography.title)
                            .foregroundStyle(AppTheme.text)
                        Text("모든 항목은 필수예요. 원장님·선생님이 확인하면 알림장과 사진을 볼 수 있어요.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.subText)
                        PetRegistrationFormView(form: $form, showErrors: showErrors)

                        Text("유치원 철학 및 운영규칙")
                            .font(AppTheme.Typography.title)
                            .foregroundStyle(AppTheme.text)
                        KindergartenPolicyView()
                        policyAgreement
                    }


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

                    Text(roleNotice)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)

                    Button(action: submit) {
                        if session.isLoading {
                            ProgressView().tint(AppTheme.buttonText)
                        } else {
                            Text(submitTitle)
                        }
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(session.isLoading)
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("회원가입")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .onAppear { session.errorMessage = nil }
            .onChange(of: role) { _, _ in
                showErrors = false
                session.errorMessage = nil
            }
        }
    }

    /// 철학과 운영규칙에 동의하는 체크 (동의해야 가입할 수 있어요)
    private var policyAgreement: some View {
        let isMissing = showErrors && !agreedToPolicy
        return Button {
            agreedToPolicy.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: agreedToPolicy ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(agreedToPolicy ? AppTheme.statusApproved : AppTheme.subText)
                Text("위 철학과 운영규칙을 읽었고, 지키겠습니다. *")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(minHeight: 44)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isMissing ? AppTheme.statusRejected : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(agreedToPolicy ? .isSelected : [])
    }

    /// 유형별 안내 문구
    private var roleNotice: String {
        switch role {
        case .owner: "원장 가입은 서비스 운영자의 승인이 필요해요. 승인되면 아이디와 비밀번호로 로그인할 수 있어요."
        case .teacher: "선생님은 원장님이 만든 초대 코드로만 가입할 수 있어요. 가입 후에는 아이디와 비밀번호로 로그인해요."
        default: "가입 후에는 로그인 화면에서 아이디와 비밀번호를 입력해 들어가요."
        }
    }

    private var submitTitle: String {
        switch role {
        case .owner: "가입 신청하기"
        case .parent: "가입하고 승인 요청하기"
        default: "가입하기"
        }
    }

    /// 로그인 화면에 보여줄 가입 완료 안내
    private var completionMessage: String {
        role == .owner
            ? "가입 신청이 접수됐어요. 서비스 운영자가 승인하면 아이디와 비밀번호로 로그인할 수 있어요."
            : "가입이 완료됐어요! 아이디와 비밀번호로 로그인해 주세요."
    }

    private var accountCard: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            TextField("\(nameLabel) *", text: $name)
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
            SecureField("비밀번호 확인 *", text: $passwordConfirm)
                .padding(12)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            if role == .teacher {
                TextField("원장님께 받은 초대 코드 *", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .foregroundStyle(AppTheme.text)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func submit() {
        showErrors = true
        guard allMissing.isEmpty else { return }
        let profile = role == .parent ? form.makeProfile() : nil
        if role == .parent && profile == nil { return }

        Task {
            // 1) 계정 만들기  2) (보호자) 반려견을 '대기중'으로 등록  3) 로그인 화면으로 돌아가기
            guard let user = await session.register(name: name, id: userID, password: password, role: role, inviteCode: inviteCode) else { return }
            store.register(user: user)
            if let profile {
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
            }
            onCompleted(clean(userID).lowercased(), completionMessage)
            dismiss()
        }
    }
}

#Preview("보호자 가입") {
    SignUpView { _, _ in }
        .environment(SessionStore())
        .environment(NotebookStore())
}

#Preview("선생님 가입") {
    SignUpView(initialRole: .teacher) { _, _ in }
        .environment(SessionStore())
        .environment(NotebookStore())
}

#Preview("원장 가입 (다크)") {
    SignUpView(initialRole: .owner) { _, _ in }
        .environment(SessionStore())
        .environment(NotebookStore())
        .preferredColorScheme(.dark)
}
