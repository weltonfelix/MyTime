//
//  TimerView.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import SwiftUI

struct TimerControls: View {
    let vm: TimerViewModel
    let date: Date
    var start: (() async -> Void)? = nil

    private var buttonLabel: LocalizedStringKey {
        if vm.isEnded {
            return "Restart"
        }
        return vm.isTimerRunning ? "Pause" : "Continue"
    }

    private var buttonIcon: String {
        if vm.isEnded {
            return "arrow.counterclockwise"
        }
        return vm.isTimerRunning ? "pause" : "play"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(
                vm.displayTime(at: date)
                    .formattedAsTimer
            )
            .font(.system(size: 64))
            .monospacedDigit()
            .accessibilityLabel("Time remaining")
            .accessibilityValue(Text(vm.displayTime(at: date).formattedForAccessibility))
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ProgressIndicator(
                        isExpanded: vm.isActive,
                        large: true,
                        progress: vm.progress(at: date)
                    )
                }

                Button(
                    buttonLabel,
                    systemImage: buttonIcon
                ) {
                    if vm.isEnded {
                        vm.restartTimer()
                    } else {
                        if vm.isTimerRunning {
                            vm.pauseTimer()
                        } else {
                            Task {
                                if let start { await start() }
                                else { await vm.startTimer() }
                            }
                        }
                    }

                }
                .labelStyle(.iconOnly)
                .controlSize(.extraLarge)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
            }
        }
    }
}

struct TimerView: View {
    let activity: Activity
    @State private var idleModel: TimerViewModel
    private let session = TimerViewModel.shared
    private var vm: TimerViewModel { session.belongs(to: activity) ? session : idleModel }

    init(activity: Activity) {
        self.activity = activity
        _idleModel = State(initialValue: TimerViewModel(duration: TimeInterval((activity.durationInMin ?? 30) * 60)))
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            TimerControls(vm: vm, date: context.date) {
                if session.belongs(to: activity) { await session.startTimer() }
                else { await session.startSession(for: activity) }
            }
                .onChange(of: context.date) { _, now in
                    guard vm.isTimerRunning else { return }
                    vm.checkEnd(at: now)
                }
        }

        .navigationBarTitleDisplayMode(
            .inline
        )
        .onChange(of: vm.isTimerRunning) { _, running in
            guard vm.isActive else { return }
            let remaining = vm.displayTime(at: .now).formattedForAccessibility
            let announcement = running
                ? String(localized: "Timer running. \(remaining) remaining. Pause timer.")
                : String(localized: "Timer paused. \(remaining) remaining. Resume timer.")
            var spokenAnnouncement = AttributedString(announcement)
            spokenAnnouncement.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(spokenAnnouncement).post()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    "Restart",
                    systemImage: "arrow.counterclockwise",
                    action: vm.restartTimer
                ).labelStyle(.iconOnly)
                    .disabled(!session.belongs(to: activity))
            }

        }
    }
}

#Preview {
    NavigationStack {
        TimerView(activity: Activity(hobby: Hobby(title: "Read", hobbyDescription: ""), durationInMin: 1))
            .navigationTitle("Timer")
    }
}
