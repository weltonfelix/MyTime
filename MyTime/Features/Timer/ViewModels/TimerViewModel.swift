//
//  TimerViewModel.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class TimerViewModel {
    static let shared = TimerViewModel(duration: 0, defaults: .standard)

    private(set) var duration: TimeInterval
    private(set) var activityID: PersistentIdentifier?
    private var hobbyID: PersistentIdentifier?
    private let defaults: UserDefaults?

    private struct Snapshot: Codable {
        var activityID: PersistentIdentifier
        var hobbyID: PersistentIdentifier
        var duration: TimeInterval
        var timerStartDate: Date?
        var remainingOnPause: TimeInterval?
        var isEnded: Bool
    }

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
        guard duration > 0 else { return 0 }
        return max(
            0,
            1 - remainingTime(at: date) / duration
        )
    }

    private var soundManager = SoundManager()

    init(duration: TimeInterval, defaults: UserDefaults? = nil) {
        self.duration = duration
        self.defaults = defaults
        if let data = defaults?.data(forKey: "hobbyTimerSession"),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
           snapshot.duration > 0, snapshot.duration <= 720 * 60 {
            activityID = snapshot.activityID
            hobbyID = snapshot.hobbyID
            self.duration = snapshot.duration
            timerStartDate = snapshot.timerStartDate
            remainingOnPause = snapshot.remainingOnPause
            isEnded = snapshot.isEnded
        }
    }

    func belongs(to activity: Activity) -> Bool {
        activityID == activity.persistentModelID && hobbyID == activity.hobby?.persistentModelID
    }

    func startSession(for activity: Activity) async {
        guard let hobby = activity.hobby, !activity.isDeleted,
              let minutes = activity.durationInMin, (1...720).contains(minutes) else { return }
        restartTimer()
        activityID = activity.persistentModelID
        hobbyID = hobby.persistentModelID
        duration = TimeInterval(minutes * 60)
        await startTimer()
    }

    func reconcile(activities: [Activity]) {
        guard activityID != nil else { return }
        guard activities.contains(where: belongs) else {
            restartTimer()
            return
        }
        checkEnd(at: .now)
    }

    private func persist() {
        guard let activityID, let hobbyID else {
            defaults?.removeObject(forKey: "hobbyTimerSession")
            return
        }
        let snapshot = Snapshot(activityID: activityID, hobbyID: hobbyID, duration: duration, timerStartDate: timerStartDate,
            remainingOnPause: remainingOnPause, isEnded: isEnded)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults?.set(data, forKey: "hobbyTimerSession")
        }
    }
    
    func startTimer() async {
        guard !isTimerRunning, !isEnded, duration > 0 else { return }
        let owner = activityID
        await PomodoroViewModel.shared.restartPomodoro()
        guard activityID == owner, !PomodoroViewModel.shared.hasActiveSession else { return }
        let elapsedTime =
        remainingOnPause.map { duration - $0 } ?? 0
        timerStartDate = .now - elapsedTime
        remainingOnPause = nil
        persist()

        await scheduleNotification(in: remainingTime(at: .now))
    }

    func pauseTimer() {
        guard isTimerRunning else { return }
        remainingOnPause = remainingTime(at: .now)
        timerStartDate = nil
        NotificationsService.shared.removeAll()
        persist()
    }

    func restartTimer() {
        activityID = nil
        hobbyID = nil
        remainingOnPause = nil
        timerStartDate = nil
        isEnded = false
        NotificationsService.shared.removeAll()
        persist()
    }

    private func stopTimer() {
        remainingOnPause = nil
        timerStartDate = nil
        isEnded = true
        persist()
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

    private func scheduleNotification(in interval: TimeInterval) async {
        guard interval > 0 else { return }

        let title = String(localized: "How was your break?")
        let body = String(localized: "Your hobby time is up.")
        await NotificationsService.shared
            .sendNotification(title: title, body: body, in: interval)
    }
}
