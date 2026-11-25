import SwiftUI

/// 응가 횟수, 몸무게(kg, 소수점 둘째 자리), 식사량(g, 5 단위) 입력 칸 모음.
/// 알림장 작성 화면에서 쓰고, 항목마다 스위치를 켜야 기록돼요.
struct HealthInputFields: View {
    @Binding var state: HealthInputState

    private static let maxPoop = 20
    private static let mealStep = 5
    private static let maxMeal = 1000

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            poopCard
            weightCard
            mealCard
            HealthExtraFields(input: $state.extra)
        }
    }

    // MARK: 응가 (횟수)

    private var poopCard: some View {
        card("응가 횟수") {
            Toggle("응가 기록하기", isOn: $state.logPoop)
                .tint(AppTheme.buttonShadow)
            if state.logPoop {
                HStack(spacing: 24) {
                    Spacer()
                    Button {
                        state.poop = max(0, state.poop - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 40))
                    }
                    .accessibilityLabel("응가 횟수 줄이기")
                    .disabled(state.poop == 0)

                    Text("\(state.poop)")
                        .font(AppTheme.Typography.counterNumber)
                        .foregroundStyle(AppTheme.text)
                        .frame(minWidth: 60)

                    Button {
                        state.poop = min(Self.maxPoop, state.poop + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 40))
                    }
                    .accessibilityLabel("응가 횟수 늘리기")
                    .disabled(state.poop == Self.maxPoop)
                    Spacer()
                }
                .foregroundStyle(AppTheme.softButtonText)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 몸무게 (kg, 소수점 둘째 자리)

    private var weightCard: some View {
        card("몸무게 (kg)") {
            Toggle("몸무게 기록하기", isOn: $state.logWeight)
                .tint(AppTheme.buttonShadow)
            if state.logWeight {
                HStack(spacing: 0) {
                    Picker("몸무게", selection: $state.weightWhole) {
                        ForEach(0...99, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 90, height: 110)
                    .clipped()

                    Text(".").font(AppTheme.Typography.title)

                    Picker("소수점 첫째 자리", selection: $state.weightTenth) {
                        ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 110)
                    .clipped()

                    Picker("소수점 둘째 자리", selection: $state.weightHundredth) {
                        ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 110)
                    .clipped()

                    Text("kg").font(AppTheme.Typography.headline).padding(.leading, 6)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: 식사량 (g, 5 단위)

    private var mealCard: some View {
        card("식사량 (g, 5g 단위)") {
            Toggle("식사량 기록하기", isOn: $state.logMeal)
                .tint(AppTheme.buttonShadow)
            if state.logMeal {
                Picker("식사량", selection: $state.mealGrams) {
                    ForEach(Array(stride(from: 0, through: Self.maxMeal, by: Self.mealStep)), id: \.self) { grams in
                        Text("\(grams) g").tag(grams)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
                .clipped()
            }
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

#Preview("기록 입력 칸") {
    ScrollView {
        HealthInputFields(state: .constant(HealthInputState(record: HealthRecord.samples().first, suggestedWeight: nil)))
            .padding()
    }
    .background(AppTheme.background)
}
