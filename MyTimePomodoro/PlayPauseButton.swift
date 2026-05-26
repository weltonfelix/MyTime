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
        Button(intent: PauseTimerIntent()) {
            Image(systemName: context.state.remainingOnPause != nil ? "play" : "pause")
        }
        .labelStyle(.iconOnly)
        .tint(.accent)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
    }
}
