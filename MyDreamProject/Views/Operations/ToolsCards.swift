import SwiftUI

/// 홈 화면의 "운영 메뉴" 카드가 여는 창 종류
private enum ToolSheetKind: Identifiable {
    case petList
    case petDetail(String)
    case admissions
    case admission(String)
    case reservations(String?)
    case consults(String?)
    case billing
    case attendance

    var id: String {
        switch self {
        case .petList: "petList"
        case .petDetail(let id): "petDetail-\(id)"
        case .admissions: "admissions"
        case .admission(let id): "admission-\(id)"
        case .reservations(let id): "reservations-\(id ?? "")"
        case .consults(let id): "consults-\(id ?? "")"
        case .billing: "billing"
        case .attendance: "attendance"
        }
    }
}

/// 카드 안의 한 줄 메뉴
private struct ToolRow: View {
    let symbol: String
    let title: LocalizedStringKey
    var subtitle: String? = nil
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(AppTheme.softButtonText)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.avatar, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.subText)
                    }
                }
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(AppTheme.Typography.caption2Bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(AppTheme.statusRejected, in: Capsule())
                }
                Image(systemName: "chevron.right").foregroundStyle(AppTheme.subText)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// 원장·선생님 홈의 운영 메뉴 카드
struct StaffToolsCard: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(AdmissionStore.self) private var admission
    @Environment(ReservationStore.self) private var reservations
    @Environment(BillingStore.self) private var billing
    @State private var sheet: ToolSheetKind?

    var body: some View {
        if let user = session.currentUser, Permissions.canVerifyAdmission(user) {
            let inProgress = notebook.pets.filter {
                $0.status != .rejected && admission.record(petID: $0.id).decision == .inProgress
            }.count
            let waiting = reservations.visibleReservations(for: user).filter { $0.status == .requested }.count
            let unpaid = Permissions.canManageBilling(user) ? billing.unpaid().count : 0
            VStack(alignment: .leading, spacing: 4) {
                Text("운영 메뉴")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                ToolRow(symbol: "dog.fill", title: "반려견 상세 페이지", subtitle: String(localized: "프로필·연락처·병력·기록 모아 보기")) { sheet = .petList }
                ToolRow(symbol: "person.badge.plus", title: "신규 원생 입학", subtitle: String(localized: "증명서 확인 · 체험 · 평가 · 승인"), badge: inProgress) { sheet = .admissions }
                ToolRow(symbol: "calendar.badge.clock", title: "예약 관리", subtitle: String(localized: "확정 대기 예약을 처리해요"), badge: waiting) { sheet = .reservations(nil) }
                ToolRow(symbol: "lock.bubble.fill", title: "1:1 상담", subtitle: String(localized: "보호자와 나눈 비공개 상담")) { sheet = .consults(nil) }
                ToolRow(symbol: "ticket.fill",
                        title: Permissions.canManageBilling(user) ? "이용권 · 결제" : "이용권",
                        subtitle: Permissions.canManageBilling(user) ? String(localized: "남은 횟수 · 만료일 · 미결제") : String(localized: "남은 횟수 · 만료일"),
                        badge: unpaid) { sheet = .billing }
                ToolRow(symbol: "calendar.badge.checkmark", title: "월별 출석 현황", subtitle: String(localized: "한 달 출석을 확인해요")) { sheet = .attendance }
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
            .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
            .sheet(item: $sheet) { sheet in
                ToolSheetContent(kind: sheet)
            }
        }
    }
}

/// 보호자 홈에서 고른 반려견에 대한 운영 메뉴 카드
struct ParentToolsCard: View {
    let pet: Pet

    @Environment(BillingStore.self) private var billing
    @Environment(AdmissionStore.self) private var admission
    @State private var sheet: ToolSheetKind?

    var body: some View {
        let unpaid = billing.unpaid(petIDs: [pet.id]).count
        let record = admission.record(petID: pet.id)
        VStack(alignment: .leading, spacing: 4) {
            Text("\(pet.name) 메뉴")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            ToolRow(symbol: "dog.fill", title: "상세 페이지", subtitle: String(localized: "연락처 · 알레르기 · 복용약 · 기록")) { sheet = .petDetail(pet.id) }
            ToolRow(symbol: "person.badge.plus", title: "입학 절차", subtitle: record.decision.displayName) { sheet = .admission(pet.id) }
            ToolRow(symbol: "calendar.badge.plus", title: "예약", subtitle: String(localized: "이용 · 상담 · 픽업 · 드롭")) { sheet = .reservations(pet.id) }
            ToolRow(symbol: "lock.bubble.fill", title: "1:1 상담", subtitle: String(localized: "원장님·선생님과 비공개 상담")) { sheet = .consults(pet.id) }
            ToolRow(symbol: "ticket.fill", title: "이용권 · 결제", subtitle: String(localized: "남은 횟수 · 만료일 · 결제 내역"), badge: unpaid) { sheet = .billing }
            ToolRow(symbol: "calendar.badge.checkmark", title: "월별 출석 현황") { sheet = .attendance }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
        .sheet(item: $sheet) { sheet in
            ToolSheetContent(kind: sheet)
        }
    }
}

private struct ToolSheetContent: View {
    let kind: ToolSheetKind

    var body: some View {
        switch kind {
        case .petList: PetListSheet()
        case .petDetail(let id): PetDetailSheet(petID: id)
        case .admissions: AdmissionListSheet()
        case .admission(let id): AdmissionDetailSheet(petID: id)
        case .reservations(let id): ReservationSheet(initialPetID: id)
        case .consults(let id): ConsultListSheet(initialPetID: id)
        case .billing: BillingSheet()
        case .attendance: AttendanceMonthSheet()
        }
    }
}

/// 원장·선생님이 반려견을 골라 상세 페이지로 들어가는 목록
struct PetListSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(PetDetailStore.self) private var details

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    let pets = session.currentUser.map { notebook.opsPets(for: $0) } ?? []
                    if pets.isEmpty { OpsEmptyCard(text: "승인된 반려견이 없어요") }
                    ForEach(pets) { pet in
                        NavigationLink {
                            ScrollView { PetDetailContent(petID: pet.id).padding(AppTheme.Spacing.large) }
                                .background(AppTheme.background.ignoresSafeArea())
                                .navigationTitle(pet.name)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 12) {
                                Group {
                                    if let photo = pet.profilePhoto {
                                        PhotoImageView(source: photo)
                                    } else {
                                        AppTheme.avatar.overlay { Image(systemName: "dog.fill").foregroundStyle(AppTheme.softButtonText) }
                                    }
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pet.name).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.text)
                                    Text("\(pet.breed) · 보호자 \(notebook.authorName(pet.ownerID))")
                                        .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.subText)
                                }
                                Spacer()
                                if details.detail(petID: pet.id).hasBehaviorAlert {
                                    OpsPill(text: String(localized: "주의"), color: AppTheme.statusPending)
                                }
                                Image(systemName: "chevron.right").foregroundStyle(AppTheme.subText)
                            }
                            .opsCard(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("반려견 상세 페이지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { CloseButton() } }
        }
    }
}
