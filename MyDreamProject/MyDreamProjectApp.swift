//
//  MyDreamProjectApp.swift
//  MyDreamProject
//
//  Created by 추규아 on 11/23/26.
//

import SwiftUI

@main
struct MyDreamProjectApp: App {
    /// 로그인한 사람 정보. 앱 전체 화면이 함께 씁니다.
    @State private var session = SessionStore()

    /// 앱이 지원하는 언어
    private static let supportedLanguages = ["ko", "en", "ja", "vi"]

    /// 기기에서 선택한 언어 중 앱이 지원하는 첫 번째 언어 (없으면 영어)
    private static var appLocale: Locale {
        for identifier in Locale.preferredLanguages {
            let locale = Locale(identifier: identifier)
            if let code = locale.language.languageCode?.identifier, supportedLanguages.contains(code) {
                return locale
            }
        }
        return Locale(identifier: "en")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.locale, Self.appLocale)
        }
    }
}
