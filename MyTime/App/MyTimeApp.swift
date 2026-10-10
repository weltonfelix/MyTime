//
//  MyTimeApp.swift
//  MyTime
//
//  Created by Welton Felix on 15/05/26.
//

import SwiftData
import SwiftUI

@main
struct MyTimeApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .modelContainer(for: Routine.self)
        }
    }
}
