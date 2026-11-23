import SwiftUI
import UIKit

/// 사진 한 장을 보여주는 화면 조각. 사진이 가짜(샘플)든, 고른 사진이든, 서버 사진이든 같은 방식으로 씁니다.
struct PhotoImageView: View {
    let source: PhotoSource
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            switch source {
            case .placeholder(let symbol, let colorIndex):
                PlaceholderPhoto(symbol: symbol, colorIndex: colorIndex)
            case .data(let data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                } else {
                    PlaceholderPhoto(symbol: "photo", colorIndex: 0)
                }
            case .video(let url):
                VideoThumbnailView(url: url, contentMode: contentMode)
            case .remote(let url):
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: contentMode)
                    } else if phase.error != nil {
                        PlaceholderPhoto(symbol: "exclamationmark.triangle", colorIndex: 0)
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .clipped()
    }
}

/// 영상 파일의 첫 장면을 작은 사진으로 보여줍니다.
private struct VideoThumbnailView: View {
    let url: URL
    let contentMode: ContentMode
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                PlaceholderPhoto(symbol: "play.rectangle.fill", colorIndex: 3)
            }
        }
        .task { image = await VideoThumbnail.make(url) }
    }
}

/// 샘플용 가짜 사진 (그라데이션 배경 + 그림)
struct PlaceholderPhoto: View {
    let symbol: String
    let colorIndex: Int

    private var colors: [Color] {
        let palette: [[Color]] = [
            [Color(red: 0.65, green: 0.48, blue: 1.0), Color(red: 1.0, green: 0.60, blue: 0.82)],
            [Color(red: 1.0, green: 0.48, blue: 0.48), Color(red: 1.0, green: 0.77, blue: 0.54)],
            [Color(red: 0.44, green: 0.75, blue: 0.17), Color(red: 0.83, green: 0.93, blue: 0.35)],
            [Color(red: 0.30, green: 0.72, blue: 0.94), Color(red: 0.60, green: 0.91, blue: 0.78)]
        ]
        return palette[abs(colorIndex) % palette.count]
    }

    var body: some View {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                GeometryReader { proxy in
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: proxy.size.width * 0.45, height: proxy.size.height * 0.45)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
    }
}

/// 반려견 이름표 여러 개를 눌러서 고르는 줄 (사진글 태그용)
struct PetTagPicker: View {
    let pets: [Pet]
    @Binding var selection: Set<String>

    var body: some View {
        if pets.isEmpty {
            Text("태그할 수 있는 승인된 반려견이 없어요")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.subText)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.small) {
                    ForEach(pets) { pet in
                        chip(for: pet)
                    }
                }
            }
        }
    }

    private func chip(for pet: Pet) -> some View {
        let isOn = selection.contains(pet.id)
        return Button {
            if isOn { selection.remove(pet.id) } else { selection.insert(pet.id) }
        } label: {
            Label(pet.name, systemImage: isOn ? "checkmark.circle.fill" : "circle")
                .font(AppTheme.Typography.headline)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .foregroundStyle(isOn ? AppTheme.buttonText : AppTheme.softButtonText)
                .background(isOn ? AnyShapeStyle(AppTheme.button) : AnyShapeStyle(AppTheme.softButton),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 태그된 반려견 이름을 작게 보여주는 줄
struct PetNameTags: View {
    let names: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(names, id: \.self) { name in
                Text("#\(name)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.softButtonText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.softButton, in: Capsule())
            }
        }
    }
}

#Preview("사진 모음") {
    VStack {
        HStack {
            PhotoImageView(source: .placeholder(symbol: "dog.fill", colorIndex: 0))
            PhotoImageView(source: .placeholder(symbol: "tree.fill", colorIndex: 2))
        }
        .frame(height: 140)
        PetNameTags(names: ["보리", "몽실"])
        PetTagPicker(pets: SampleData.pets.filter(\.isApproved), selection: .constant(["pet-bori"]))
    }
    .padding()
}
