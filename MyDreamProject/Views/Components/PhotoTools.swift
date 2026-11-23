import SwiftUI
import UIKit
import Photos
import AVFoundation
import UniformTypeIdentifiers

/// 영상 파일의 첫 장면을 사진으로 뽑는 도구
enum VideoThumbnail {
    static func make(_ url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        guard let result = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: result.image)
    }
}

/// 사진을 화면에 그리거나 파일로 바꾸는 도구
enum PhotoRenderer {
    /// 저장·공유용 실제 이미지로 변환 (가짜 사진은 그림으로 만들어 줍니다)
    @MainActor
    static func uiImage(for source: PhotoSource) async -> UIImage? {
        switch source {
        case .data(let data):
            return UIImage(data: data)
        case .placeholder(let symbol, let colorIndex):
            let renderer = ImageRenderer(
                content: PlaceholderPhoto(symbol: symbol, colorIndex: colorIndex)
                    .frame(width: 1024, height: 1024)
            )
            renderer.scale = 1
            return renderer.uiImage
        case .video(let url):
            return await VideoThumbnail.make(url)
        case .remote(let url):
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return UIImage(data: data)
        }
    }

    @MainActor
    static func pngData(for source: PhotoSource) async -> Data? {
        await uiImage(for: source)?.pngData()
    }

    /// 사진 앱에서 고른 큰 사진을 가볍게 줄입니다 (JPEG 80%)
    static func compressed(_ data: Data) -> Data {
        UIImage(data: data)?.jpegData(compressionQuality: 0.8) ?? data
    }
}

/// 기기의 사진 앱에 저장하는 도구 (사진과 영상 모두)
enum PhotoSaver {
    /// 저장 결과를 사용자에게 보여줄 문장으로 돌려줍니다.
    static func save(_ sources: [PhotoSource]) async -> String {
        // Info 설정에 안내 문구가 없으면 앱이 꺼질 수 있어서 먼저 확인합니다.
        guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil else {
            return String(localized: "사진 저장 권한 안내 문구가 아직 설정되지 않았어요. (프로젝트 설정 필요)")
        }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return String(localized: "사진 저장 권한이 꺼져 있어요. 설정 앱에서 허용해 주세요.")
        }

        var images: [UIImage] = []
        var videoURLs: [URL] = []
        for source in sources {
            if case .video(let url) = source {
                videoURLs.append(url)
            } else if let image = await PhotoRenderer.uiImage(for: source) {
                images.append(image)
            }
        }
        let total = images.count + videoURLs.count
        guard total > 0 else { return String(localized: "저장할 사진을 불러오지 못했어요.") }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                for image in images {
                    _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                for url in videoURLs {
                    _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
            }
            return String(localized: "\(total)개를 사진 앱에 저장했어요.")
        } catch {
            return String(localized: "저장에 실패했어요. 잠시 후 다시 시도해 주세요.")
        }
    }
}

/// 공유(ShareLink)에 쓰는 사진 (영상은 파일 주소로 따로 공유)
struct SharablePhoto: Transferable {
    let source: PhotoSource

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { photo in
            guard let data = await PhotoRenderer.pngData(for: photo.source) else {
                throw CocoaError(.fileReadUnknown)
            }
            return data
        }
    }
}

/// 사진 앱에서 고른 영상을 앱 안으로 가져오는 도구
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let destination = folder.appendingPathComponent("\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}
