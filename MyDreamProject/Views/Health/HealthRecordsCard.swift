import SwiftUI

/// 홈 화면의 건강 기록 카드: 최근 5일을 일자별로 넘겨 보고, 고른 날의 기록을 보여줍니다.
/// 원장·선생님은 강아지 이름을 눌러 그 아이의 기록 화면으로 들어가 기입할 수 있고,
/// 보호자는 내 반려견 기록만 볼 수 있어요.
struct HealthRecordsCard: View {
    /// 보여줄 반려견 (nil이면 승인된 반려견 전체)
    let petIDs: [String]?
    let canEdit: Bool

    @Environment(NotebookStore.self) private var notebook
    @Environment(HealthRecordStore.self) private var health
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var target: Target?

    /// 열 화면: 강아지 한 마리의 기록 화면 / 고른 날 바로 입력
    private enum Target: Identifiable {
        case log(petID: String)
        case edit(petID: String, day: Date)

        var id: String {
            switch self {
            case .log(let petID): "log-\(petID)"
            case .edit(let petID, let day): "edit-\(petID)-\(day.timeIntervalSince1970)"
            }
        }
    }

    private var calendar: Calendar { Calendar.current }

    private var pets: [Pet] {
        notebook.pets.filter { $0.isApproved && (petIDs?.contains($0.id) ?? true) }
    }

    /// 오늘부터 5일 전까지
    private var recentDays: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<5).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Label("건강 기록", systemImage: "heart.text.square.fill")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)

            dayChips

            DatePicker(
                "다른 날짜",
                selection: Binding(
                    get: { selectedDay },
                    set: { selectedDay = calendar.startOfDay(for: $0) }
                ),
                in: ...Date.now,
                displayedComponents: .date
            )
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.subText)

            records
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
        .sheet(item: $target) { target in
            switch target {
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

    private var dayChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recentDays, id: \.self) { day in
                    dayChip(day)
                }
            }
        }
    }

    private func dayChip(_ day: Date) -> some View {
        let isOn = calendar.isDate(day, inSameDayAs: selectedDay)
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 2) {
                Text(HealthDayLabel.title(for: day)).font(AppTheme.Typography.headline)
                Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption2)
            }
            .padding(.horizontal, 14)
            .frame(minWidth: 64, minHeight: 52)
            .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
            .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: 그날의 기록

    @ViewBuilder
    private var records: some View {
        let shown = pets.filter { canEdit || health.record(petID: $0.id, on: selectedDay) != nil }
        if shown.isEmpty {
            Text("이 날은 기록이 없어요")
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
