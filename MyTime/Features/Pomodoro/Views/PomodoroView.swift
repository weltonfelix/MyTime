//
//  PomodoroView.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftUI

extension TimeInterval {
    var formattedAsTimer: String {
        let total = Int(self)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct PomodoroControls: View {
    let vm: PomodoroViewModel
    let date: Date

    private var buttonLabel: String {
        if vm.status == .ended {
            return "Reiniciar"
        }
        return vm.isTimerRunning ? "Pausar" : "Continuar"
    }

    private var buttonIcon: String {
        if vm.status == .ended {
            return "arrow.counterclockwise"
        }
        return vm.isTimerRunning ? "pause" : "play"
    }

    var body: some View {
        VStack(spacing: 4) {
            VStack {
                Text(vm.status.rawValue).font(.headline)
                Text(
                    vm.displayTime(at: date)
                        .formattedAsTimer
                )
                .font(.system(size: 64))
                .monospacedDigit()
            }
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<vm.totalStages, id: \.self) {
                        stage in
                        ProgressIndicator(
                            isExpanded: vm.currentStage == stage
                                && vm.status == .focus
                                && vm.hasActiveSession,
                            progress: vm.progress(
                                for: stage,
                                at: date
                            )
                        )
                    }
                }

                Button(
                    buttonLabel,
                    systemImage: buttonIcon
                ) {
                    if vm.status == .ended {
                        vm.restartPomodoro()
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

struct PomodoroView: View {
    private let vm = PomodoroViewModel()
    private var showAccentBackground: Bool {
        vm.status != .focus
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if showAccentBackground {
                Color.accent.ignoresSafeArea().transition(.opacity)
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                PomodoroControls(vm: vm, date: context.date)
                    .onChange(of: context.date) { _, now in
                        guard vm.status != .ended else { return }
                        vm.advanceStage(at: now)
                    }
            }
        }
        .sensoryFeedback(
            .success,
            trigger: vm.status
        ) {
            (
                _: PomodoroViewModel.PomodoroStatus,
                new: PomodoroViewModel.PomodoroStatus
            ) in
            new == .rest || new == .longRest || new == .ended
        }
        .sensoryFeedback(
            .warning,
            trigger: vm.status
        ) {
            (
                _: PomodoroViewModel.PomodoroStatus,
                new: PomodoroViewModel.PomodoroStatus
            ) in
            new == .focus && vm.currentStage != 0
        }
        .animation(.default, value: vm.status)
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    "Reiniciar",
                    systemImage: "arrow.counterclockwise",
                    action: vm.restartPomodoro
                ).labelStyle(.iconOnly)
            }

        }
        .colorScheme(showAccentBackground ? .dark : colorScheme)
        .toolbarColorScheme(showAccentBackground ? .dark : colorScheme)
    }
}

#Preview {
    NavigationStack {
        PomodoroView()
            .navigationTitle("Pomodoro")
    }
}
