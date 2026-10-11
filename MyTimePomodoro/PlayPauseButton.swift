//
//  PlayPauseButton.swift
//  MyTime
//
//  Created by Welton Felix on 26/05/26.
//

import AppIntents
import SwiftUI
import WidgetKit

struct PlayPauseButton: View {
    var context: ActivityViewContext<MyTimePomodoroAttributes>

    var body: some View {
        let isRunning = context.state.endDate != nil && context.state.remainingOnPause == nil && !context.isStale
        Button(intent: PauseTimerIntent(activityID: context.activityID)) {
            Image(systemName: isRunning ? "pause" : "play")
        }
        .accessibilityLabel(isRunning ? "Pause" : "Continue")
        .labelStyle(.iconOnly)
        .tint(.accent)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
    }
}
