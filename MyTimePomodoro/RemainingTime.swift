//
//  ProgressProvider.swift
//  MyTimePomodoroExtension
//
//  Created by Welton Felix on 26/05/26.
//

import SwiftUI
import WidgetKit

struct RemainingTime: View {
    var context: ActivityViewContext<MyTimePomodoroAttributes>

    var body: some View {
        if let remaining = context.state.remainingOnPause {
            Text(ceil(remaining).formattedAsTimer)
                .monospacedDigit()
                .font(.largeTitle)
        } else if let end = context.state.endDate {
            Text(
                timerInterval: .now...end,
                countsDown: true
            )
            .monospacedDigit()
            .font(.largeTitle)
        } else {
            Text("0:00")
                .monospacedDigit()
                .font(.largeTitle)
        }
    }
}
