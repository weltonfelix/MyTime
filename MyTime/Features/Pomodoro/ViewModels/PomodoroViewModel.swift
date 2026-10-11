//
//  PomodoroViewModel.swift
//  MyTime
//
//  Created by Welton Felix on 23/05/26.
//

import ActivityKit
import SwiftUI
import SwiftData

@MainActor
@Observable
final class PomodoroViewModel {
    static let shared = PomodoroViewModel(activity: ActivityKit.Activity<MyTimePomodoroAttributes>.activities.first)

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
    private var isSwitchingSession = false
    private(set) var taskID: PersistentIdentifier?
    private(set) var taskTitle: String?

    var hasSession: Bool { taskID != nil && status != .ended }

    func belongs(to task: MyTask) -> Bool { taskID == task.persistentModelID }

    func startSession(for task: MyTask) async {
        guard !isSwitchingSession else { return }
        isSwitchingSession = true
        defer { isSwitchingSession = false }
        await restartPomodoro()
        taskID = task.persistentModelID
        taskTitle = String(task.taskDescription.prefix(200))
        await startTimer()
    }

    func reconcile(tasks: [MyTask]) async {
        guard !isSwitchingSession else { return }
        let activities = ActivityKit.Activity<MyTimePomodoroAttributes>.activities
        let valid = activities.filter { activity in
            tasks.contains { $0.persistentModelID == activity.attributes.taskID }
        }
        let selected = valid.first { $0.id == liveActivity?.id } ?? valid.first
        for activity in activities where activity.id != selected?.id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if let selected {
            if liveActivity?.id != selected.id { adopt(selected) }
            await advanceStage(at: .now)
        } else if taskID != nil && !tasks.contains(where: { $0.persistentModelID == taskID }) {
            await restartPomodoro()
        } else if liveActivity != nil {
            await restartPomodoro()
        }
    }

    func taskID(for url: URL) -> PersistentIdentifier? {
        guard url.scheme == "mytime", url.host == "pomodoro",
              url.pathComponents.count == 2,
              let activity = ActivityKit.Activity<MyTimePomodoroAttributes>.activities.first(where: {
                  $0.id == url.lastPathComponent
              }) else { return nil }
        return activity.attributes.taskID
    }

    private func adopt(_ activity: ActivityKit.Activity<MyTimePomodoroAttributes>) {
        liveActivity = activity
        taskID = activity.attributes.taskID
        taskTitle = activity.attributes.taskTitle
        restore(activity.content.state)
    }

    init(activity: ActivityKit.Activity<MyTimePomodoroAttributes>? = nil) {
        if let activity { adopt(activity) }
    }

    func restore(_ state: MyTimePomodoroAttributes.ContentState) {
        currentStage = state.currentSession
        status = PomodoroStatus(rawValue: state.pomodoroStatus) ?? .focus
        remainingOnPause = state.remainingOnPause
        timerStartDate = state.endDate?.addingTimeInterval(-currentStageDuration)
        isTimerRunning = state.endDate != nil && remainingOnPause == nil
    }

    func toggleTimer(activityID: String) async {
        guard let activity = ActivityKit.Activity<MyTimePomodoroAttributes>.activities.first(where: { $0.id == activityID }) else { return }
        if liveActivity?.id != activity.id {
            adopt(activity)
        }
        advanceStageIfNeeded(at: .now)
        if status == .ended {
            await endLiveActivity()
        } else if isTimerRunning {
            await pauseTimer()
        } else {
            await startTimer()
        }
    }

    private var contentState: MyTimePomodoroAttributes.ContentState {
        .init(currentSession: currentStage, pomodoroStatus: status.rawValue,
              endDate: endDate, stageDuration: currentStageDuration,
              remainingOnPause: remainingOnPause)
    }

    func startTimer() async {
        let elapsedTime =
            remainingOnPause.map { currentStageDuration - $0 } ?? 0
        timerStartDate = .now - elapsedTime
        remainingOnPause = nil
        isTimerRunning = true

        let startDate = timerStartDate
        await scheduleNotification(in: remainingTime(at: .now))
        guard isTimerRunning, timerStartDate == startDate else { return }
        if liveActivity == nil {
            startLiveActivity()
        } else {
            await updateLiveActivity()
        }
    }

    func pauseTimer() async {
        isTimerRunning = false
        remainingOnPause = remainingTime(at: .now)
        NotificationsService.shared.removeAll()
        await updateLiveActivity()
    }

    func restartPomodoro() async {
        taskID = nil
        taskTitle = nil
        currentStage = 0
        status = .focus
        stopTimer()
        NotificationsService.shared.removeAll()
        await endLiveActivity()
    }

    private func stopTimer() {
        isTimerRunning = false
        remainingOnPause = nil
        timerStartDate = nil
    }

    func startLiveActivity() {
        let attributes = MyTimePomodoroAttributes(taskID: taskID, taskTitle: taskTitle)

        do {
            liveActivity = try ActivityKit.Activity<MyTimePomodoroAttributes>
                .request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: endDate)
                )
        } catch {
            print("Erro: \(error)")
        }
    }

    private func updateLiveActivity() async {
        guard let liveActivity else { return }

        let newState = contentState

        await liveActivity.update(.init(state: newState, staleDate: isTimerRunning ? endDate : nil))
    }

    private func endLiveActivity() async {
        let activity = liveActivity
        liveActivity = nil
        await activity?.end(.init(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
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

    func advanceStage(at now: Date) async {
        if advanceStageIfNeeded(at: now) {
            if status == .ended { await endLiveActivity() }
            else { await updateLiveActivity() }
        }
    }

    @discardableResult
    private func advanceStageIfNeeded(at now: Date) -> Bool {
        guard isTimerRunning && remainingTime(at: now) <= 0 else { return false }

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

        if status != .ended { remainingOnPause = currentStageDuration }
        soundManager.playChime()
        return true
    }

    private func scheduleNotification(in interval: TimeInterval) async {
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

        await NotificationsService.shared
            .sendNotification(title: title, body: body, in: interval)
    }
}
