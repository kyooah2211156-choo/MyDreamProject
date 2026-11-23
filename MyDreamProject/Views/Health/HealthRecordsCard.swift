import SwiftUI

/// 홈 화면의 건강 기록 카드: 처음엔 오늘 기록을 보여주고, '다른 날짜' 버튼으로 날짜를 골라 지난 기록을 봅니다.
/// 원장·선생님은 강아지 이름을 눌러 그 아이의 기록 화면으로 들어가 기입할 수 있고,
/// 보호자는 내 반려견 기록만 볼 수 있어요.
struct HealthRecordsCard: View {
    /// 보여줄 반려견 (nil이면 승인된 반려견 전체)
    let petIDs: [String]?
    let canEdit: Bool
    /// 오늘 등원해 있는 반려견 id. 넘기면 '오늘'을 볼 때 이 아이들만 보여줘요.
    /// (지난 날은 그날 누가 왔는지 기록이 없어서 전체를 보여줘요)
    var attendingPetIDs: Set<String>? = nil

    @Environment(NotebookStore.self) private var notebook
    @Environment(HealthRecordStore.self) private var health
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var target: Target?
    /// 카드를 펼쳐 둘지. 접어 두면 다음에 앱을 열어도 접힌 채로 있어요.
    @AppStorage("healthCardExpanded") private var isExpanded = true

    /// 열 화면: 날짜 고르기 / 강아지 한 마리의 기록 화면 / 고른 날 바로 입력
    private enum Target: Identifiable {
        case pickDay
        case log(petID: String)
        case edit(petID: String, day: Date)

        var id: String {
            switch self {
            case .pickDay: "pick-day"
            case .log(let petID): "log-\(petID)"
            case .edit(let petID, let day): "edit-\(petID)-\(day.timeIntervalSince1970)"
            }
        }
    }

    private var calendar: Calendar { Calendar.current }

    private var pets: [Pet] {
        let showsOnlyAttending = calendar.isDateInToday(selectedDay) && attendingPetIDs != nil
        return notebook.pets.filter {
            $0.isApproved
                && (petIDs?.contains($0.id) ?? true)
                && (!showsOnlyAttending || attendingPetIDs?.contains($0.id) == true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            header
            if isExpanded {
                dayBar
                records
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
        .sheet(item: $target) { target in
            switch target {
            case .pickDay:
                HealthDayPickerSheet(initialDay: selectedDay) { selectedDay = calendar.startOfDay(for: $0) }
            case .log(let petID):
                PetHealthLogView(petID: petID)
            case .edit(let petID, let day):
                HealthRecordEditorView(
                    petID: petID,
                    day: day,
                    existing: health.record(petID: petID, on: day),
                    suggestedWeight: health.latestWeight(petID: petID)
                )
            }
        }
    }

    // MARK: 일자 선택

    private var header: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Label("건강 기록", systemImage: "heart.text.square.fill")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.text)
                    Image(systemName: "chevron.down")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(isExpanded ? String(localized: "누르면 접어요") : String(localized: "누르면 펼쳐요")))
            Spacer()
            if isExpanded {
                Button {
                    target = .pickDay
                } label: {
                    Label("다른 날짜", systemImage: "calendar")
                        .font(AppTheme.Typography.caption)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .foregroundStyle(AppTheme.softButtonText)
                        .background(AppTheme.softButton, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 지금 보고 있는 날짜. 오늘이 아니면 '오늘' 버튼으로 바로 돌아올 수 있어요.
    private var dayBar: some View {
        HStack {
            Text(HealthDayLabel.title(for: selectedDay))
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            Text(selectedDay.formatted(.dateTime.weekday(.abbreviated)))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
            Spacer()
            if !calendar.isDateInToday(selectedDay) {
                Button("오늘") { selectedDay = calendar.startOfDay(for: .now) }
                    .font(AppTheme.Typography.caption)
                    .frame(minHeight: 44)
                    .foregroundStyle(AppTheme.softButtonText)
            }
        }
    }

    // MARK: 그날의 기록

    @ViewBuilder
    private var records: some View {
        let shown = pets.filter { canEdit || health.record(petID: $0.id, on: selectedDay) != nil }
        if shown.isEmpty {
            let message: LocalizedStringKey = calendar.isDateInToday(selectedDay) && attendingPetIDs != nil
                ? "오늘 등원한 반려견이 없어요" : "이 날은 기록이 없어요"
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.subText)
                .frame(maxWidth: .infinity, minHeight: 56)
        } else {
            ForEach(shown) { pet in
                row(pet)
            }
        }
    }

    @ViewBuilder
    private func row(_ pet: Pet) -> some View {
        let record = health.record(petID: pet.id, on: selectedDay)
        if canEdit {
            // 이름 쪽을 누르면 그 강아지의 기록 화면, 오른쪽 버튼을 누르면 고른 날을 바로 입력
            HStack(spacing: 4) {
                Button {
                    target = .log(petID: pet.id)
                } label: {
                    rowContent(pet, record: record, showsChevron: true)
                }
                .buttonStyle(.plain)

                Button {
                    target = .edit(petID: pet.id, day: selectedDay)
                } label: {
                    Image(systemName: record == nil ? "plus.circle.fill" : "pencil.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppTheme.softButtonText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("기록 입력")
            }
        } else {
            rowContent(pet, record: record, showsChevron: false)
        }
    }

    private func rowContent(_ pet: Pet, record: HealthRecord?, showsChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pet.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subText)
                        .accessibilityHidden(true)
                }
                Spacer()
            }
            if let record {
                HealthMetricPills(record: record)
            } else {
                Text("기록 전")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .frame(minHeight: 44)
        .background(AppTheme.softButton.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 지난 날짜를 고르는 창. 오늘까지만 고를 수 있어요.
private struct HealthDayPickerSheet: View {
    let onPick: (Date) -> Void
    @State private var day: Date
    @Environment(\.dismiss) private var dismiss

    init(initialDay: Date, onPick: @escaping (Date) -> Void) {
        _day = State(initialValue: initialDay)
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
            DatePicker("다른 날짜", selection: $day, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(AppTheme.Spacing.large)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle("다른 날짜")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("확인") {
                            onPick(day)
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 날짜 이름 (오늘 / 어제 / 월·일)
enum HealthDayLabel {
    static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "오늘") }
        if calendar.isDateInYesterday(day) { return String(localized: "어제") }
        return day.formatted(.dateTime.month().day())
    }
}

/// 기록 하나의 응가·몸무게·식사량을 작은 알약 모양으로 보여줍니다.
struct HealthMetricPills: View {
    let record: HealthRecord

    var body: some View {
        HStack(spacing: 8) {
            pill("toilet.fill", String(localized: "응가 \(record.poopCount)회"))
            if let weight = record.weightKg {
                pill("scalemass.fill", "\(weight.formatted(.number.precision(.fractionLength(0...2)))) kg")
            }
            if let meal = record.mealGrams {
                pill("fork.knife", "\(meal) g")
            }
        }
    }

    private func pill(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppTheme.card, in: Capsule())
    }
}

#Preview("원장·선생님 (입력 가능)") {
    ScrollView {
        HealthRecordsCard(petIDs: nil, canEdit: true).padding()
    }
    .background(AppTheme.background)
    .environment(SessionStore(currentUser: SampleData.teacher))
    .environment(NotebookStore())
    .environment(HealthRecordStore())
}

#Preview("보호자 (보기만, 다크)") {
    ScrollView {
        HealthRecordsCard(petIDs: ["pet-bori"], canEdit: false).padding()
    }
    .background(AppTheme.background)
    .environment(SessionStore(currentUser: SampleData.parent))
    .environment(NotebookStore())
    .environment(HealthRecordStore())
    .preferredColorScheme(.dark)
}
