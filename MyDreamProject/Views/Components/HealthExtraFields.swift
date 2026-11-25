import SwiftUI

/// 소변 횟수, 응가 상태, 식욕, 구토 여부, 오늘의 컨디션, 특이사항 입력 칸 모음.
/// 항목마다 스위치를 켜야 기록되고, 꺼 두면 '미기록'으로 남아요. (0회와 구분돼요)
struct HealthExtraFields: View {
    @Binding var input: HealthExtraInput

    private static let maxUrine = 30

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            urineCard
            poopStatusCard
            appetiteCard
            vomitCard
            conditionCard
            noteCard
        }
    }

    private var urineCard: some View {
        card("소변 횟수") {
            Toggle("소변 기록하기", isOn: $input.logUrine)
                .tint(AppTheme.buttonShadow)
            if input.logUrine {
                HStack(spacing: 24) {
                    Spacer()
                    Button {
                        input.urine = max(0, input.urine - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 40))
                    }
                    .accessibilityLabel("소변 횟수 줄이기")
                    .disabled(input.urine == 0)

                    Text("\(input.urine)")
                        .font(AppTheme.Typography.counterNumber)
                        .foregroundStyle(AppTheme.text)
                        .frame(minWidth: 60)

                    Button {
                        input.urine = min(Self.maxUrine, input.urine + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 40))
                    }
                    .accessibilityLabel("소변 횟수 늘리기")
                    .disabled(input.urine == Self.maxUrine)
                    Spacer()
                }
                .foregroundStyle(AppTheme.softButtonText)
                .buttonStyle(.plain)
            }
        }
    }

    private var poopStatusCard: some View {
        card("응가 상태") {
            Toggle("응가 상태 기록하기", isOn: $input.logPoopStatus)
                .tint(AppTheme.buttonShadow)
            if input.logPoopStatus {
                ChoiceChips(options: PoopStatus.allCases, selection: $input.poopStatus) { $0.displayName }
            }
        }
    }

    private var appetiteCard: some View {
        card("식욕") {
            Toggle("식욕 기록하기", isOn: $input.logAppetite)
                .tint(AppTheme.buttonShadow)
            if input.logAppetite {
                ChoiceChips(options: AppetiteLevel.allCases, selection: $input.appetite) { $0.displayName }
            }
        }
    }

    private var vomitCard: some View {
        card("구토") {
            Toggle("구토 여부 기록하기", isOn: $input.logVomit)
                .tint(AppTheme.buttonShadow)
            if input.logVomit {
                ChoiceChips(options: [false, true], selection: $input.vomited) {
                    $0 ? String(localized: "구토 있음") : String(localized: "없음")
                }
            }
        }
    }

    private var conditionCard: some View {
        card("오늘의 컨디션") {
            Toggle("컨디션 기록하기", isOn: $input.logCondition)
                .tint(AppTheme.buttonShadow)
            if input.logCondition {
                ChoiceChips(options: ConditionLevel.allCases, selection: $input.condition) { $0.displayName }
            }
        }
    }

    private var noteCard: some View {
        card("건강 특이사항 · 비고") {
            TextField("예: 오후에 기침을 조금 했어요", text: $input.note, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func card<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            content()
        }
        .foregroundStyle(AppTheme.text)
        .padding(AppTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}

/// 보기 중에서 하나를 고르는 버튼 줄 (고르지 않은 상태가 없는 버전)
struct ChoiceChips<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        // 보기가 많아도 줄이 바뀌도록 가로 스크롤로 둡니다.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isOn = selection == option
                    Button {
                        selection = option
                    } label: {
                        Text(title(option))
                            .font(AppTheme.Typography.headline)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                            .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}
