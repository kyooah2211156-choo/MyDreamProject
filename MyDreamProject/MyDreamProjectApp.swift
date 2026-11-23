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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
