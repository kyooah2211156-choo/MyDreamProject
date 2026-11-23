import SwiftUI
import AVKit

/// 사진이면 사진을, 영상이면 재생 화면을 보여주는 한 장짜리 화면 조각
struct MediaPageView: View {
    let source: PhotoSource
    var contentMode: ContentMode = .fill

    var body: some View {
        if case .video(let url) = source {
            VideoPlayerPage(url: url)
        } else {
            PhotoImageView(source: source, contentMode: contentMode)
        }
    }
}

/// 영상 재생 (Apple 기본 재생기 사용)
struct VideoPlayerPage: View {
    let url: URL
    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                if player.currentItem == nil {
                    player.replaceCurrentItem(with: AVPlayerItem(url: url))
                }
            }
            .onDisappear { player.pause() }
    }
}

#Preview("사진") {
    MediaPageView(source: .placeholder(symbol: "dog.fill", colorIndex: 0))
        .frame(height: 240)
}
