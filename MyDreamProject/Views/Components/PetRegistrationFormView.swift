import SwiftUI

/// 반려견 정보 입력 칸 모음. 모든 항목이 필수이고, 빠진 칸은 빨간 테두리로 알려줘요.
struct PetRegistrationFormView: View {
    @Binding var form: PetFormState
    let showErrors: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            field(.name) {
                inputField("예: 보리", text: $form.name)
            }
            field(.breed) {
                inputField("예: 말티즈", text: $form.breed)
            }
            field(.gender) {
                OptionChips(options: PetGender.allCases, selection: $form.gender) { $0.displayName }
            }
            field(.birthDate) {
                birthDateInput
            }
            field(.age) {
                HStack {
                    inputField("예: 3", text: $form.ageText)
                        .keyboardType(.numberPad)
                    Text("살").font(AppTheme.Typography.headline).foregroundStyle(AppTheme.text)
                }
                Text("직접 적어 주세요. 0~30 사이 숫자예요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            field(.neutered) {
                OptionChips(options: [true, false], selection: $form.isNeutered) { $0 ? String(localized: "예") : String(localized: "아니오") }
            }
            field(.animalRegistration) {
                OptionChips(options: [true, false], selection: $form.isAnimalRegistered) { $0 ? String(localized: "예") : String(localized: "아니오") }
                Text("동물등록 여부만 체크해 주세요. 등록번호 등은 원장님이 직접 확인해요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.subText)
            }
            field(.vaccination) {
                OptionChips(options: VaccinationStatus.allCases, selection: $form.vaccination) { $0.displayName }
            }
            field(.allergy) {
                inputField("직접 적어 주세요 (없으면 '없음')", text: $form.allergy, multiline: true)
            }
            field(.health) {
                inputField("예: 건강해요 / 슬개골이 약해요", text: $form.healthCondition, multiline: true)
            }
            field(.temperament) {
                inputField("예: 활발하고 사람을 좋아해요", text: $form.temperament, multiline: true)
            }
        }
    }

    /// 생년월일은 선택 사항이에요. 고르면 비어 있는 연령 칸을 계산해서 채워 주고, 고친 뒤에도 직접 바꿀 수 있어요.
    @ViewBuilder
    private var birthDateInput: some View {
        if form.birthDate == nil {
            Button {
                setBirthDate(Calendar.current.date(byAdding: .year, value: -2, to: .now) ?? .now)
            } label: {
                Label("생년월일 선택하기", systemImage: "calendar")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(AppTheme.softButtonText)
                    .background(AppTheme.softButton, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                DatePicker(
                    "생년월일",
                    selection: Binding(get: { form.birthDate ?? .now }, set: { setBirthDate($0) }),
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                Spacer()
                Button("지우기") { form.birthDate = nil }
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.softButtonText)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private func setBirthDate(_ date: Date) {
        form.birthDate = date
        if form.ageText.trimmingCharacters(in: .whitespaces).isEmpty {
            form.ageText = String(PetProfile.years(from: date))
        }
    }

    private func inputField(_ placeholder: LocalizedStringKey, text: Binding<String>, multiline: Bool = false) -> some View {
        Group {
            if multiline {
                TextField(placeholder, text: text, axis: .vertical).lineLimit(2...4)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .padding(12)
        .background(AppTheme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(AppTheme.text)
    }

    private func field<Content: View>(_ field: PetFormField, @ViewBuilder content: () -> Content) -> some View {
        let isMissing = showErrors && form.missingFields.contains(field)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(field.title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.text)
                if field.isRequired {
                    Text("*").foregroundStyle(AppTheme.statusRejected)
                } else {
                    Text("(선택)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.subText)
                }
                if isMissing {
                    Text("꼭 입력해 주세요")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.statusRejected)
                }
            }
            content()
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isMissing ? AppTheme.statusRejected : Color.clear, lineWidth: 2)
        }
    }
}

/// 보기 중에서 하나를 고르는 버튼 줄
private struct OptionChips<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value?
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                chip(option)
            }
        }
    }

    private func chip(_ option: Value) -> some View {
        let isOn = selection == option
        return Button {
            selection = option
        } label: {
            Text(title(option))
                .font(AppTheme.Typography.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton),
                            in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview("빈 양식 (오류 표시)") {
    ScrollView {
        PetRegistrationFormView(form: .constant(PetFormState()), showErrors: true)
            .padding()
    }
    .background(AppTheme.background)
}

#Preview("일부 입력 (다크)") {
    var state = PetFormState()
    state.name = "보리"
    state.allergy = "닭고기"
    return ScrollView {
        PetRegistrationFormView(form: .constant(state), showErrors: false)
            .padding()
    }
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
