//
//  PauseTimerIntent.swift
//  MyTime
//
//  Created by Welton Felix on 26/05/26.
//

import AppIntents

struct PauseTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Timer"
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.dev.weltonfelix.MyTime")
        defaults?.set(true, forKey: "pauseRequested")
        return .result()
    }
}

