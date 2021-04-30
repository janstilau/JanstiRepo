//
//  LandmarkApp.swift
//  Landmark
//
//  Created by JustinLau on 2021/4/28.
//

import SwiftUI

@main
struct LandmarkApp: App {
    /*
     Scene 提供 content 进行展示.
     */
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

extension View {
    func debug() -> Self {
        print(Mirror(reflecting: self).subjectType)
        return self
    }
}
