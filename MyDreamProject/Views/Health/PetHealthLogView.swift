import SwiftUI

/// 강아지 한 마리의 건강 기록 화면 (원장·선생님): 최근 5일을 날짜별로 보고, 날짜마다 들어가서 기입합니다.
struct PetHealthLogView: View {
    let petID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(NotebookStore.self) private var notebook
    @Environment(HealthRecordStore.self) private var health
    @State private var editorDay: EditorDay?
    @State private var otherDay = Calendar.current.startOfDay(for: .now)

    private struct EditorDay: Identifiable {
        let day: Date
        var id: TimeInterval { day.timeIntervalSince1970 }
    }

    private var calendar: Calendar { Calendar.current }
    private var pet: Pet? { notebook.pets.first { $0.id == petID } }

    private var recentDays: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<5).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser, Permissions.canEditHealthRecords(user), let pet {
                    content(pet)
                } else {
                    Text("원장님과 선생님만 기록할 수 있어요")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.subText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background.ignoresSafeArea())
                }
            }
            .navigationTitle("건강 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }

    private func content(_ pet: Pet) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.text)
                    Text(pet.breed)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }

                Text("최근 5일")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                    .padding(.top, 4)
                ForEach(recentDays, id: \.self) { day in
                    dayRow(day)
                }

                Text("다른 날짜 기록하기")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                    .padding(.top, 8)
                HStack {
                    DatePicker(
                        "날짜",
                        selection: Binding(
                            get: { otherDay },
                            set: { otherDay = calendar.startOfDay(for: $0) }
                        ),
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    Spacer()
                    Button("이 날짜 기록하기") { editorDay = EditorDay(day: otherDay) }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.softButtonText)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .sheet(item: $editorDay) { item in
            HealthRecordEditorView(
                petID: petID,
                day: item.day,
                existing: health.record(petID: petID, on: item.day),
                suggestedWeight: health.latestWeight(petID: petID)
            )
        }
    }

    private func dayRow(_ day: Date) -> some View {
        let record = health.record(petID: petID, on: day)
        return Button {
            editorDay = EditorDay(day: day)
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(HealthDayLabel.title(for: day)).font(AppTheme.Typography.headline)
                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption2)
                }
                .foregroundStyle(AppTheme.softButtonText)
                .frame(width: 64)

                if let record {
                    HealthMetricPills(record: record)
                } else {
                    Text("기록 전")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
                Spacer(minLength: 0)
                Image(systemName: record == nil ? "plus.circle.fill" : "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.softButtonText)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(minHeight: 56)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview("보리 (선생님)") {
    PetHealthLogView(petID: "pet-bori")
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
}

#Preview("보호자 (접근 불가, 다크)") {
    PetHealthLogView(petID: "pet-bori")
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
        .preferredColorScheme(.dark)
}
