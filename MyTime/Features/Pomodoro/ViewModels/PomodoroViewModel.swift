//
//  PomodoroViewModel.swift
//  MyTime
//
//  Created by Welton Felix on 23/05/26.
//

import SwiftUI

@Observable
final class PomodoroViewModel {
    enum PomodoroStatus: String {
        case focus = "Foco"
        case rest = "Intervalo"
        case longRest = "Intervalo Longo"
        case ended = "Ciclo Completo!"
    }

    let totalStages = 4

    private let focusDuration: TimeInterval = 10  //5 * 60
    private let restDuration: TimeInterval = 5  // * 60
    private let longRestDuration: TimeInterval = 3  //0 * 60

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

    func startTimer() {
        let elapsedTime =
            remainingOnPause.map { currentStageDuration - $0 } ?? 0
        timerStartDate = .now - elapsedTime
        remainingOnPause = nil
        isTimerRunning = true
    }

    func pauseTimer() {
        isTimerRunning = false
        remainingOnPause = remainingTime(at: .now)
    }

    func stopTimer() {
        isTimerRunning = false
        remainingOnPause = nil
        timerStartDate = nil
    }

    func restartPomodoro() {
        currentStage = 0
        status = .focus
        stopTimer()
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
                return max(0, 1 - ceil(remainingTime(at: date)) / currentStageDuration)  // Focus
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
        soundManager.playChime()
    }
}
