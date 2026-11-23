import SwiftUI
import CoreText
import Observation

/// 지금 고른 글꼴. 바뀌면 글자를 쓰는 화면들이 알아서 다시 그려져요.
@Observable
final class AppFontSelection {
    static let shared = AppFontSelection()
    var style: AppFontStyle = .system
}

extension AppFontStyle {
    /// 앱에 넣은 글꼴 파일의 이름 (보통 / 굵게). 기본 글꼴이면 nil
    var fontNames: (regular: String, bold: String)? {
        switch self {
        case .system: nil
        case .round: ("Jua-Regular", "Jua-Regular")                 // 주아: 굵기가 하나뿐이에요
        case .gothic: ("NanumGothic", "NanumGothicBold")
        case .serif: ("NanumMyeongjo", "NanumMyeongjoBold")
        }
    }

    /// 설정 화면에 보여줄 글꼴 이름
    var credit: String? {
        switch self {
        case .system: nil
        case .round: "주아 · Jua"
        case .gothic: "나눔고딕 · Nanum Gothic"
        case .serif: "나눔명조 · Nanum Myeongjo"
        }
    }
}

/// 글꼴을 만들어 주는 도구. 글자 크기 설정(Dynamic Type)에 맞춰 커지고 작아져요.
enum AppFont {
    /// 기기 기본 글자 크기('보통')일 때의 크기
    private static func baseSize(_ textStyle: Font.TextStyle) -> CGFloat {
        switch textStyle {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }

    private static func isBold(_ weight: Font.Weight) -> Bool {
        weight == .semibold || weight == .bold || weight == .heavy || weight == .black
    }

    /// 지정한 글꼴로 글자 모양을 만듭니다. (설정 화면의 글꼴 미리보기에서도 써요)
    static func font(style: AppFontStyle, textStyle: Font.TextStyle, weight: Font.Weight) -> Font {
        guard let names = style.fontNames else {
            return Font.system(textStyle, design: .rounded).weight(weight)
        }
        let name = isBold(weight) ? names.bold : names.regular
        return Font.custom(name, size: baseSize(textStyle), relativeTo: textStyle)
    }

    /// 지금 고른 글꼴로 글자 모양을 만듭니다.
    static func font(_ textStyle: Font.TextStyle, weight: Font.Weight) -> Font {
        font(style: AppFontSelection.shared.style, textStyle: textStyle, weight: weight)
    }

    /// 크기를 직접 정한 글자 (큰 숫자 등). 기본 글꼴일 때는 크기가 고정이에요.
    static func sized(_ size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) -> Font {
        let style = AppFontSelection.shared.style
        guard let names = style.fontNames else {
            return Font.system(size: size, weight: weight, design: .rounded)
        }
        return Font.custom(isBold(weight) ? names.bold : names.regular, size: size, relativeTo: textStyle)
    }
}

/// 앱에 넣은 글꼴 파일(.ttf)을 앱이 켜질 때 등록합니다.
enum FontRegistrar {
    static func registerAll() {
        var urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        urls += Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in Set(urls) {
            // 이미 등록돼 있으면 오류가 나지만 문제는 없어요.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
