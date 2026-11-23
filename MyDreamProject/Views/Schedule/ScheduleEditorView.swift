import SwiftUI

enum ScheduleEditorMode: Identifiable {
    case create(Date)
    case edit(ScheduleEvent)

    var id: String {
        switch self {
        case .create(let date): "create-\(date.timeIntervalSince1970)"
        case .edit(let event): "edit-\(event.id)"
        }
    }
}

/// 일정 추가·수정 화면 (원장 전용)
struct ScheduleEditorView: View {
    let mode: ScheduleEditorMode
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(ScheduleStore.self) private var store

    @State private var title: String
    @State private var kind: ScheduleKind
    @State private var day: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isAllDay: Bool
    @State private var note: String
    @State private var confirmingDelete = false

    init(mode: ScheduleEditorMode) {
        self.mode = mode
        let calendar = Calendar.current
        switch mode {
        case .create(let date):
            _title = State(initialValue: "")
            _kind = State(initialValue: .program)
            _day = State(initialValue: date)
            _startTime = State(initialValue: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date) ?? date)
            _endTime = State(initialValue: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: date) ?? date)
            _isAllDay = State(initialValue: false)
            _note = State(initialValue: "")
        case .edit(let event):
            _title = State(initialValue: event.title)
            _kind = State(initialValue: event.kind)
            _day = State(initialValue: event.start)
            _startTime = State(initialValue: event.start)
            _endTime = State(initialValue: event.end)
            _isAllDay = State(initialValue: event.isAllDay)
            _note = State(initialValue: event.note)
        }
    }

    private var existingEvent: ScheduleEvent? {
        if case .edit(let event) = mode { return event }
        return nil
    }

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 날짜와 시간을 합쳐 하나의 시각으로 만듭니다.
    private func combine(day: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day) ?? day
    }

    private var isTimeRangeValid: Bool {
        isAllDay || combine(day: day, time: endTime) > combine(day: day, time: startTime)
    }

    private var canSave: Bool { !cleanTitle.isEmpty && isTimeRangeValid }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("제목 (예: 산책 프로그램)", text: $title)
                    Picker("종류", selection: $kind) {
                        ForEach(ScheduleKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("날짜와 시간") {
                    DatePicker("날짜", selection: $day, displayedComponents: .date)
                    Toggle("종일", isOn: $isAllDay)
                    if !isAllDay {
                        DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("종료", selection: $endTime, displayedComponents: .hourAndMinute)
                        if !isTimeRangeValid {
                            Text("종료 시간은 시작 시간보다 늦어야 해요.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.statusRejected)
                        }
                    }
                }
                Section("메모 (선택)") {
                    TextField("보호자에게 알릴 내용", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                if existingEvent != nil {
                    Section {
                        Button("일정 삭제", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(existingEvent == nil ? String(localized: "일정 추가") : String(localized: "일정 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(!canSave)
                }
            }
            .confirmationDialog("이 일정을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { delete() }
            }
        }
    }

    private func save() {
        guard let user = session.currentUser, Permissions.canEditSchedule(user), canSave else { return }
        let calendar = Calendar.current
        let start = isAllDay ? calendar.startOfDay(for: day) : combine(day: day, time: startTime)
        let end = isAllDay ? start : combine(day: day, time: endTime)
        store.save(ScheduleEvent(
            id: existingEvent?.id ?? UUID().uuidString,
            title: cleanTitle,
            kind: kind,
            start: start,
            end: end,
            isAllDay: isAllDay,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        dismiss()
    }

    private func delete() {
        guard let user = session.currentUser, Permissions.canEditSchedule(user),
              let event = existingEvent else { return }
        store.delete(id: event.id)
        dismiss()
    }
}

#Preview("일정 추가") {
    ScheduleEditorView(mode: .create(.now))
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(ScheduleStore())
}

#Preview("일정 수정 (다크)") {
    ScheduleEditorView(mode: .edit(ScheduleEvent.samples().first ?? ScheduleEvent(
        id: "x", title: "샘플", kind: .program, start: .now, end: .now.addingTimeInterval(3600),
        isAllDay: false, note: "")))
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(ScheduleStore())
        .preferredColorScheme(.dark)
}
