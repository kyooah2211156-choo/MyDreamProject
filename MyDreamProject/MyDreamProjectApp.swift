//
//  MyDreamProjectApp.swift
//  MyDreamProject
//
//  Created by 추규아 on 11/23/26.
//

import SwiftUI

@main
struct MyDreamProjectApp: App {
    var body: some Scene {
        WindowGroup {
            TeacherHomeView(viewModel: .sample)
        }
    }
}
