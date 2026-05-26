//
//  MyTimeShortcuts.swift
//  MyTime
//
//  Created by Welton Felix on 26/05/26.
//

import AppIntents

struct MyTimeShortcuts: AppShortcutsProvider {
    
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetDailyRoutineIntent(),
            phrases: [
                "Show today's routine in \(.applicationName)",
                "Check my routine in \(.applicationName)",
                "Check today's activities in \(.applicationName)"
            ],
            shortTitle: "Read Daily Routine",
            systemImageName: "calendar.badge.clock"
        )
    }
}
