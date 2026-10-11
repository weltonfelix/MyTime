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
        guard context.state.stageDuration > 0 else { return 1 }
        let remaining = context.state.remainingOnPause
            ?? context.state.endDate?.timeIntervalSince(.now)
            ?? context.state.stageDuration
        return min(1, max(0, 1 - remaining / context.state.stageDuration))
    }

    @ViewBuilder
    private func progressIndicator(for context: ActivityViewContext<MyTimePomodoroAttributes>) -> some View {
        if context.state.remainingOnPause == nil, let end = context.state.endDate,
           context.state.stageDuration > 0 {
            ProgressView(timerInterval: end.addingTimeInterval(-context.state.stageDuration)...end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.accent)
        } else {
            LiveActivityProgressIndicator(progress: progress(for: context))
        }
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MyTimePomodoroAttributes.self) { context in
            VStack {
                if let title = context.attributes.taskTitle {
                    Text(title).font(.subheadline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Text(LocalizedStringKey(context.state.pomodoroStatus)).font(.headline)
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
                progressIndicator(for: context)
            }.padding()
                .widgetURL(MyTimePomodoroAttributes.url(activityID: context.activityID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    (context.attributes.taskTitle.map { Text($0) }
                        ?? Text(LocalizedStringKey(context.state.pomodoroStatus)))
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
                        progressIndicator(for: context)
                    }
                    .padding([.bottom, .horizontal], 4)
                }
            } compactLeading: {
                Text(LocalizedStringKey(context.state.pomodoroStatus))
            } compactTrailing: {
                RemainingTime(context: context, font: .caption2)
                    .frame(width: 48, alignment: .trailing)
            } minimal: {
                progressIndicator(for: context).frame(width: 30)
            }
            .widgetURL(MyTimePomodoroAttributes.url(activityID: context.activityID))
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
