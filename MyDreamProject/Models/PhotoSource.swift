import Foundation

/// 사진이 어디에 있는지를 나타냅니다.
/// 지금은 가짜 사진(색 배경 + 그림)을 쓰고, 나중에 서버 주소(remote)로 바꿉니다.
enum PhotoSource: Codable, Hashable {
    /// 샘플용 가짜 사진 (SF Symbols 그림 이름, 배경색 번호)
    case placeholder(symbol: String, colorIndex: Int)
    /// 사진 앱에서 고른 실제 사진 데이터
    case data(Data)
    /// 서버에 올라간 사진 주소 (서버 연동 단계에서 사용)
    case remote(URL)
}

/// 글 하나에 붙는 사진 한 장
struct PostPhoto: Identifiable, Codable, Hashable {
    let id: String
    var source: PhotoSource
}
