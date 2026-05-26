//
//  TimerViewModel.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import SwiftUI

@Observable
final class TimerViewModel {
    let duration: TimeInterval

    private var timerStartDate: Date? = nil
    var isTimerRunning: Bool {
        timerStartDate != nil
    }

    private var remainingOnPause: TimeInterval? = nil

    var isActive: Bool {
        isTimerRunning || remainingOnPause != nil
    }
    
    var isEnded: Bool = false

    private var endDate: Date? {
        timerStartDate?.addingTimeInterval(duration)
    }
    
    func progress (at date: Date) -> Double {
        return max(
            0,
            1 - remainingTime(at: date) / duration
        )
    }

    private var soundManager = SoundManager()

    init(duration: TimeInterval) {
        self.duration = duration
    }
    
    func startTimer() {
        let elapsedTime =
        remainingOnPause.map { duration - $0 } ?? 0
        timerStartDate = .now - elapsedTime
        remainingOnPause = nil

        scheduleNotification(in: remainingTime(at: .now))
    }

    func pauseTimer() {
        timerStartDate = nil
        remainingOnPause = remainingTime(at: .now)
        NotificationsService.shared.removeAll()
    }

    func restartTimer() {
        remainingOnPause = nil
        timerStartDate = nil
        isEnded = false
        NotificationsService.shared.removeAll()
    }

    private func stopTimer() {
        remainingOnPause = nil
        timerStartDate = nil
        isEnded = true
    }

    func remainingTime(at now: Date) -> TimeInterval {
        if let remainingOnPause {
            return remainingOnPause
        }
        
        if isEnded { return 0 }

        guard let endDate else { return duration }

        return max(0, endDate.timeIntervalSince(now))
    }

    func displayTime(at now: Date) -> TimeInterval {
        min(duration, ceil(remainingTime(at: now)))
    }

    func checkEnd(at now: Date) {
        guard isTimerRunning && remainingTime(at: now) <= 0 else { return }

        stopTimer()
        soundManager.playChime()
    }

    private func scheduleNotification(in interval: TimeInterval) {
        guard interval > 0 else { return }

        let title = "How was your break?"
        let body = "Your hobby time is up."
        Task {
            await NotificationsService.shared
                .sendNotification(title: title, body: body, in: interval)
        }
    }
}
