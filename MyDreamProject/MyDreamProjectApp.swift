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

    /// 기기에서 선택한 언어 (예: 한국어 기기면 날짜 선택기도 한글로 나와요)
    private static var appLocale: Locale {
        Locale(identifier: Locale.preferredLanguages.first ?? "ko-KR")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.locale, Self.appLocale)
        }
    }
}
