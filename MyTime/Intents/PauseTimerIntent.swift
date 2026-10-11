//
//  PauseTimerIntent.swift
//  MyTime
//
//  Created by Welton Felix on 26/05/26.
//

import AppIntents

struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause Timer"
    
    @Parameter(title: "Activity ID")
    var activityID: String

    init() {}

    init(activityID: String) {
        self.activityID = activityID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // LiveActivityIntent runs in the app; the extension only needs its declaration.
        #if !MYTIME_WIDGET_EXTENSION
        await PomodoroViewModel.shared.toggleTimer(activityID: activityID)
        #endif
        return .result()
    }
}

