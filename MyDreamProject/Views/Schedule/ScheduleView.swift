import SwiftUI

extension ScheduleKind {
    /// 달력 점과 배지에 쓰는 색
    var color: Color {
        switch self {
        case .program: AppTheme.buttonShadow
        case .freeTime: AppTheme.statusApproved
        case .event: AppTheme.statusPending
        case .closed: AppTheme.statusRejected
        }
    }
}

/// 한 달 시간표: 달력에서 날짜를 누르면 그날의 일정이 아래에 보여요.
struct ScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(ScheduleStore.self) private var store

    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var editorMode: ScheduleEditorMode?

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            if let user = session.currentUser {
                content(user)
            }
        }
    }

    private func content(_ user: User) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.large) {
                monthHeader
                calendarGrid
                legend
                dayList(user)
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("한 달 시간표")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                if Permissions.canEditSchedule(user) {
                    Button {
                        editorMode = .create(selectedDate)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("일정 추가")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            ScheduleEditorView(mode: mode)
        }
    }

    // MARK: 달 이동

    private var monthHeader: some View {
        HStack {
            Button { moveMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("이전 달")
            Spacer()
            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.text)
            Spacer()
            Button { moveMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("다음 달")
        }
        .foregroundStyle(AppTheme.softButtonText)
    }

    private func moveMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = next
        // 이번 달로 돌아오면 오늘을, 다른 달이면 1일을 선택해 둡니다.
        selectedDate = calendar.isDate(next, equalTo: .now, toGranularity: .month)
            ? calendar.startOfDay(for: .now) : next
    }

    // MARK: 달력

    private var weekdayNames: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// 달력 칸 목록 (앞쪽 빈 칸은 nil)
    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: interval.start))
        }
        return result
    }

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdayNames, id: \.self) { name in
                    Text(name)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 52) }
                }
            }
        }
        .padding(12)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let kinds = store.kinds(on: day)
        return Button {
            selectedDate = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(isSelected ? AppTheme.buttonText : (isToday ? AppTheme.softButtonText : AppTheme.text))
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(AppTheme.button)
                        } else if isToday {
                            Circle().stroke(AppTheme.softButtonText, lineWidth: 2)
                        }
                    }
                HStack(spacing: 3) {
                    ForEach(kinds.prefix(3), id: \.self) { kind in
                        Circle().fill(kind.color).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.month().day().weekday(.wide)))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(ScheduleKind.allCases, id: \.self) { kind in
                HStack(spacing: 4) {
                    Circle().fill(kind.color).frame(width: 8, height: 8)
                    Text(kind.displayName)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
            }
        }
    }

    // MARK: 선택한 날의 일정

    private func dayList(_ user: User) -> some View {
        let events = store.events(on: selectedDate)
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text(selectedDate.formatted(.dateTime.month().day().weekday(.wide)))
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            if events.isEmpty {
                Text("이 날은 등록된 일정이 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
            }
            ForEach(events) { event in
                eventRow(event, canEdit: Permissions.canEditSchedule(user))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func eventRow(_ event: ScheduleEvent, canEdit: Bool) -> some View {
        if canEdit {
            Button { editorMode = .edit(event) } label: { eventCard(event, canEdit: true) }
                .buttonStyle(.plain)
        } else {
            eventCard(event, canEdit: false)
        }
    }

    private func eventCard(_ event: ScheduleEvent, canEdit: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.kind.color)
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.isAllDay ? String(localized: "종일")
                     : "\(event.start.formatted(date: .omitted, time: .shortened)) ~ \(event.end.formatted(date: .omitted, time: .shortened))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
                HStack(spacing: 8) {
                    Text(event.title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(event.kind.displayName)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(event.kind.color, in: Capsule())
                }
                if !event.note.isEmpty {
                    Text(event.note)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                }
            }
            Spacer(minLength: 0)
            if canEdit {
                Image(systemName: "pencil")
                    .foregroundStyle(AppTheme.softButtonText)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 6, y: 3)
    }
}

#Preview("원장 (수정 가능)") {
    ScheduleView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(ScheduleStore())
}

#Preview("보호자 (보기만)") {
    ScheduleView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(ScheduleStore())
}

#Preview("선생님 (다크)") {
    ScheduleView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(ScheduleStore())
        .preferredColorScheme(.dark)
}
