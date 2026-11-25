import SwiftUI

/// 운영 화면들이 함께 쓰는 작은 조각들 (기존 카드·버튼 디자인을 그대로 따라요)

extension View {
    /// 흰 카드 + 그림자 (기존 카드와 같은 모양)
    func opsCard(padding: CGFloat = AppTheme.Spacing.large) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
            .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }
}

/// 둥근 색 배지
struct OpsPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

/// 제목 + 값 한 줄
struct OpsInfoRow: View {
    let title: String
    let value: String
    var emptyText: String = String(localized: "입력 전")

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
                .frame(width: 76, alignment: .leading)
            Text(value.isEmpty ? emptyText : value)
                .font(AppTheme.Typography.body)
                .foregroundStyle(value.isEmpty ? AppTheme.subText : AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 내용이 없을 때 보여주는 안내 카드
struct OpsEmptyCard: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.subText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}

struct OpsSectionTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.text)
    }
}

/// 반려견 한 마리를 고르는 칩 줄 (기존 훈련·알림장 화면의 칩과 같은 모양)
struct OpsPetChips: View {
    let pets: [Pet]
    @Binding var selectedID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.small) {
                ForEach(pets) { pet in
                    let isOn = (selectedID ?? pets.first?.id) == pet.id
                    Button { selectedID = pet.id } label: {
                        Text(pet.name)
                            .font(AppTheme.Typography.headline)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                            .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}

/// 입력 칸 (기존 입력 칸과 같은 연보라 바탕)
struct OpsField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var multiline = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        Group {
            if multiline {
                TextField(placeholder, text: $text, axis: .vertical).lineLimit(2...5)
            } else {
                TextField(placeholder, text: $text).keyboardType(keyboard)
            }
        }
        .padding(12)
        .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(AppTheme.text)
    }
}

/// 보호자가 볼 수 있는 반려견 / 원장·선생님이 볼 수 있는 반려견 (운영 화면 공통)
extension NotebookStore {
    /// 운영 화면에서 고를 수 있는 반려견. 보호자는 내 반려견 전부(대기·반려 포함), 직원은 승인된 반려견 전체.
    func opsPets(for user: User) -> [Pet] {
        switch user.role {
        case .parent: pets.filter { $0.ownerID == user.id }
        case .owner, .teacher: pets.filter(\.isApproved)
        case .admin: []
        }
    }

    func petName(_ id: String) -> String { pets.first { $0.id == id }?.name ?? String(localized: "알 수 없음") }
}

/// 직원 이름을 찾는 도우미 (원장·선생님 목록)
extension NotebookStore {
    var staffUsers: [User] { users.filter { $0.role == .owner || $0.role == .teacher } }
}

/// 화면 위쪽에 닫기 버튼이 있는 운영 화면 틀
struct OpsSheet<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    content()
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}
