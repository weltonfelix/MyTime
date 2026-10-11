//
//  TimerView.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import SwiftUI

struct TimerControls: View {
    @State var vm: TimerViewModel
    let date: Date

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
                        vm.isTimerRunning
                            ? vm.pauseTimer() : vm.startTimer()
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
    private let vm: TimerViewModel

    init(durationInMinutes: Int) {
        vm = .init(duration: TimeInterval(durationInMinutes * 60))
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            TimerControls(vm: vm, date: context.date)
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
            }

        }
    }
}

#Preview {
    NavigationStack {
        TimerView(durationInMinutes: 1)
            .navigationTitle("Timer")
    }
}
