//
//  PomodoroView.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftUI
import SwiftData

struct PomodoroControls: View {
    let vm: PomodoroViewModel
    let date: Date
    var start: (() async -> Void)? = nil

    private var buttonLabel: String {
        if vm.status == .ended {
            return "Restart"
        }
        return vm.isTimerRunning ? "Pause" : "Continue"
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
                Text(LocalizedStringKey(vm.status.rawValue)).font(.headline)
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
                    Task {
                        if vm.status == .ended {
                            await vm.restartPomodoro()
                        } else if vm.isTimerRunning {
                            await vm.pauseTimer()
                        } else {
                            if let start { await start() }
                            else { await vm.startTimer() }
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

struct PomodoroView: View {
    let task: MyTask
    @State private var idleModel = PomodoroViewModel()
    @State private var showSwitchConfirmation = false
    private let session = PomodoroViewModel.shared
    private var vm: PomodoroViewModel { session.belongs(to: task) ? session : idleModel }
    private var showAccentBackground: Bool {
        vm.status != .focus
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if showAccentBackground {
                Color.accent.ignoresSafeArea().transition(.opacity)
            }
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                PomodoroControls(vm: vm, date: context.date) {
                    if session.hasSession && !session.belongs(to: task) {
                        showSwitchConfirmation = true
                    } else if session.belongs(to: task) {
                        await session.startTimer()
                    } else {
                        await session.startSession(for: task)
                    }
                }
                    .onChange(of: context.date) { _, now in
                        guard vm.status != .ended else { return }
                        Task { await vm.advanceStage(at: now) }
                    }
            }
        }
        .confirmationDialog("Start a new Pomodoro?", isPresented: $showSwitchConfirmation, titleVisibility: .visible) {
            Button("End current session and start") {
                Task { await session.startSession(for: task) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end the Pomodoro for \(session.taskTitle ?? "") and start a new session for \(task.taskDescription).")
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
                    "Restart",
                    systemImage: "arrow.counterclockwise",
                    action: { Task { await vm.restartPomodoro() } }
                ).labelStyle(.iconOnly)
                    .disabled(!session.belongs(to: task))
            }

        }
        .colorScheme(showAccentBackground ? .dark : colorScheme)
        .toolbarColorScheme(showAccentBackground ? .dark : colorScheme)
    }
}

#Preview {
    NavigationStack {
        PomodoroView(task: MyTask(taskDescription: "Pomodoro"))
            .navigationTitle("Pomodoro")
    }
}
