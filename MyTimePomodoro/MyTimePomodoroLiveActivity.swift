//
//  MyTimePomodoroLiveActivity.swift
//  MyTimePomodoro
//
//  Created by Welton Felix on 25/05/26.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct MyTimePomodoroLiveActivity: Widget {
    private func progress(
        for context: ActivityViewContext<MyTimePomodoroAttributes>
    ) -> Double {
        guard let end = context.state.endDate else { return 0 }
        let elapsed =
            context.state.stageDuration
            - max(0, end.timeIntervalSince(.now))
        return elapsed / context.state.stageDuration
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MyTimePomodoroAttributes.self) { context in
            VStack {
                HStack {
                    Text(context.state.pomodoroStatus).font(.headline)
                    Spacer()
                    HStack {
                        ForEach(Array(0..<4), id: \.self) { index in
                            if index == context.state.currentSession {
                                DotProgressIndicator(
                                    progress: progress(for: context)
                                )
                            } else if index > context.state.currentSession {
                                DotProgressIndicator(progress: 0)
                            } else {
                                DotProgressIndicator(progress: 1)
                            }
                        }
                    }
                }
                HStack {
                    RemainingTime(context: context)
                    Spacer()
                    PlayPauseButton(
                        context: context
                    )
                }
                LiveActivityProgressIndicator(
                    progress: progress(for: context)
                )
            }.padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.pomodoroStatus)
                        .font(.headline)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack {
                        ForEach(0..<4, id: \.self) { index in
                            if index == context.state.currentSession {
                                DotProgressIndicator(
                                    width: 17,
                                    progress: progress(for: context)
                                )
                            } else if index > context.state.currentSession {
                                DotProgressIndicator(width: 17, progress: 0)
                            } else {
                                DotProgressIndicator(width: 17, progress: 1)
                            }
                        }
                    }
                    .padding([.trailing, .top], 4)

                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        HStack {
                            RemainingTime(context: context)
                            Spacer()
                            PlayPauseButton(
                                context: context
                            )
                        }
                        LiveActivityProgressIndicator(
                            progress: progress(for: context)
                        )
                    }
                    .padding([.bottom, .horizontal], 4)
                }
            } compactLeading: {
                Text(context.state.pomodoroStatus)
            } compactTrailing: {
                let remaining = max(
                    0,
                    (context.state.endDate ?? .now).timeIntervalSince(.now)
                )
                let minutes = Int(remaining) / 60
                Text("\(minutes < 1 ? "< 1" : String(minutes)) min")
                    .monospacedDigit()
                    .font(.caption2)
            } minimal: {
                LiveActivityProgressIndicator(
                    progress: progress(for: context)
                ).frame(width: 30)
            }
        }
    }
}

extension MyTimePomodoroAttributes {
    fileprivate static var preview: MyTimePomodoroAttributes {
        MyTimePomodoroAttributes()
    }
}

extension MyTimePomodoroAttributes.ContentState {
    fileprivate static var paused: MyTimePomodoroAttributes.ContentState {
        MyTimePomodoroAttributes
            .ContentState(
                currentSession: 1,
                pomodoroStatus: "Focus",
                endDate: .now.addingTimeInterval(25),
                stageDuration: 25,
                remainingOnPause: nil
            )
    }

    fileprivate static var running: MyTimePomodoroAttributes.ContentState {
        MyTimePomodoroAttributes
            .ContentState(
                currentSession: 1,
                pomodoroStatus: "Rest",
                endDate: .now.addingTimeInterval(2),
                stageDuration: 5,
                remainingOnPause: nil
            )
    }
}

#Preview("Notification", as: .content, using: MyTimePomodoroAttributes.preview)
{
    MyTimePomodoroLiveActivity()
} contentStates: {
    MyTimePomodoroAttributes.ContentState.paused
    MyTimePomodoroAttributes.ContentState.running
}
