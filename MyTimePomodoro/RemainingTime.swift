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
    var font: Font = .largeTitle

    var body: some View {
        let now = Date.now
        Group {
            if let remaining = context.state.remainingOnPause {
                Text(ceil(remaining).formattedAsTimer)
                    .monospacedDigit()
                    .font(font)
            } else if let end = context.state.endDate, end > now {
                Text(
                    timerInterval: now...end,
                    countsDown: true
                )
                .monospacedDigit()
                .font(font)
            } else {
                Text("0:00")
                    .monospacedDigit()
                    .font(font)
            }
        }
        .accessibilityLabel("Time remaining")
        .accessibilityValue(Text((context.state.remainingOnPause ?? max(0, context.state.endDate?.timeIntervalSince(now) ?? 0)).formattedForAccessibility))
    }
}
