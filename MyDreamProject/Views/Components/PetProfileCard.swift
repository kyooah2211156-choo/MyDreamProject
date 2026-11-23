import SwiftUI

/// 반려견이 가입할 때 적은 상세 정보를 보여주는 카드
struct PetProfileCard: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(pet.name) 정보")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.text)
            if let profile = pet.profile {
                row("성별", profile.gender.displayName)
                if let birthDate = profile.birthDate {
                    row("생년월일", birthDate.formatted(date: .long, time: .omitted))
                }
                row("연령", "\(profile.ageYears)살")
                row("중성화", profile.isNeutered ? "예" : "아니오")
                row("동물등록", profile.isAnimalRegistered ? "예" : "아니오")
                row("예방접종", profile.vaccination.displayName)
                row("알러지", profile.allergy)
                row("건강상태", profile.healthCondition)
                row("성향", profile.temperament)
            } else {
                Text("등록된 상세 정보가 없어요")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.subText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.text)
        }
    }
}

#Preview("정보 있음") {
    PetProfileCard(pet: SampleData.petPending).padding()
}

#Preview("정보 없음 (다크)") {
    PetProfileCard(pet: Pet(id: "x", name: "새싹", breed: "믹스", profilePhoto: nil, ownerID: "u",
                            status: .pending, rejectionReason: nil, requesterID: "u", reviewerID: nil))
        .padding()
        .preferredColorScheme(.dark)
}
