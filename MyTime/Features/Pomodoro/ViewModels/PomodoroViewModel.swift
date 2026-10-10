//
//  PomodoroViewModel.swift
//  MyTime
//
//  Created by Welton Felix on 23/05/26.
//

import ActivityKit
import SwiftUI

@Observable
final class PomodoroViewModel {
    enum PomodoroStatus: String {
        case focus = "Focus"
        case rest = "Interval"
        case longRest = "Long Interval"
        case ended = "Cycle Complete!"
    }

    let totalStages = 4

    private let focusDuration: TimeInterval = 25 * 60
    private let restDuration: TimeInterval = 5 * 60
    private let longRestDuration: TimeInterval = 30 * 60

    var currentStageDuration: TimeInterval {
        switch status {
        case .focus: focusDuration
        case .rest: restDuration
        case .longRest: longRestDuration
        case .ended: 0
        }
    }

    var currentStage: Int = 0
    var status: PomodoroStatus = .focus

    var isTimerRunning: Bool = false

    private var timerStartDate: Date? = nil

    private var remainingOnPause: TimeInterval? = nil

    var hasActiveSession: Bool {
        isTimerRunning || remainingOnPause != nil
    }

    private var endDate: Date? {
        timerStartDate?.addingTimeInterval(currentStageDuration)
    }

    private var soundManager = SoundManager()
    private var liveActivity: ActivityKit.Activity<MyTimePomodoroAttributes>?
    private var liveActivityUpdateTask: Task<Void, Never>?

    func startTimer() {
        let elapsedTime =
            remainingOnPause.map { currentStageDuration - $0 } ?? 0
        timerStartDate = .now - elapsedTime
        remainingOnPause = nil
        isTimerRunning = true

        observePauseRequests()
        scheduleNotification(in: remainingTime(at: .now))
        if liveActivity == nil {
            startLiveActivity()
            startLiveActivityUpdates()
        } else {
            updateLiveActivity()
        }
    }

    func pauseTimer() {
        isTimerRunning = false
        remainingOnPause = remainingTime(at: .now)
        NotificationsService.shared.removeAll()
        updateLiveActivity()
        liveActivityUpdateTask?.cancel()
    }

    func restartPomodoro() {
        currentStage = 0
        status = .focus
        stopTimer()
        NotificationsService.shared.removeAll()
        endLiveActivity()
        liveActivityUpdateTask?.cancel()
    }

    private func stopTimer() {
        isTimerRunning = false
        remainingOnPause = nil
        timerStartDate = nil
    }

    func startLiveActivity() {
        let attributes = MyTimePomodoroAttributes()
        let contentState = MyTimePomodoroAttributes.ContentState(
            currentSession: currentStage,
            pomodoroStatus: status.rawValue,
            endDate: endDate,
            stageDuration: currentStageDuration,
            remainingOnPause: remainingOnPause
        )

        do {
            liveActivity = try ActivityKit.Activity<MyTimePomodoroAttributes>
                .request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil)
                )
        } catch {
            print("Erro: \(error)")
        }
    }

    func updateLiveActivity() {
        guard let liveActivity else { return }

        let newState = MyTimePomodoroAttributes.ContentState(
            currentSession: currentStage,
            pomodoroStatus: status.rawValue,
            endDate: endDate,
            stageDuration: currentStageDuration,
            remainingOnPause: remainingOnPause
        )

        Task { @MainActor in
            await liveActivity.update(.init(state: newState, staleDate: nil))
        }
    }

    func endLiveActivity() {
        Task { @MainActor in
            await liveActivity?.end(nil, dismissalPolicy: .immediate)
            liveActivity = nil
        }
    }

    private func observePauseRequests() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let defaults = UserDefaults(
                suiteName: "group.dev.weltonfelix.MyTime"
            )
            guard defaults?.bool(forKey: "pauseRequested") ?? false else {
                return
            }
            defaults?.set(false, forKey: "pauseRequested")

            if self.isTimerRunning {
                self.pauseTimer()
            } else {
                self.startTimer()
            }
        }
    }

    func remainingTime(at now: Date) -> TimeInterval {
        if let remainingOnPause {
            return remainingOnPause
        }

        guard let endDate else { return currentStageDuration }

        return max(0, endDate.timeIntervalSince(now))
    }

    func displayTime(at now: Date) -> TimeInterval {
        min(ceil(remainingTime(at: now)), currentStageDuration)
    }

    func progress(for stage: Int, at date: Date) -> CGFloat {
        if stage < currentStage { return 1 }  // Previous stages

        if stage == currentStage {
            if status == .focus {
                return max(
                    0,
                    1 - remainingTime(at: date) / currentStageDuration
                )  // Focus
            }
            return 1  // Rest
        }

        return 0  // Next stages
    }

    func advanceStage(at now: Date) {
        guard isTimerRunning && remainingTime(at: now) <= 0 else { return }

        stopTimer()
        let isLastStage = currentStage == totalStages - 1

        if status == .focus {
            status = isLastStage ? .longRest : .rest
        } else {
            if isLastStage {
                status = .ended
            } else {
                currentStage += 1
                status = .focus
            }
        }

        updateLiveActivity()
        soundManager.playChime()
    }

    private func startLiveActivityUpdates() {
        liveActivityUpdateTask?.cancel()
        liveActivityUpdateTask = Task { @MainActor in
            while !Task.isCancelled {
                updateLiveActivity()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func scheduleNotification(in interval: TimeInterval) {
        guard interval > 0 else { return }

        let title: String
        let body: String

        switch status {
        case .focus:
            title = "Focus session complete!"
            body = "You deserve some rest."
        case .rest:
            title = "Rest session complete!"
            body = "You are ready for the next round!"
        case .longRest:
            title = "Congratulations!"
            body = "Pomodoro is over!"
        case .ended:
            return
        }

        Task {
            await NotificationsService.shared
                .sendNotification(title: title, body: body, in: interval)
        }
    }
}
