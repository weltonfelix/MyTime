import Foundation
import ActivityKit
import Testing
import SwiftData
@testable import MyTime

@MainActor
@Suite(.serialized)
struct PomodoroTests {
    @Test func restoresRunningSessionAndPausesAtRemainingTime() async {
        let model = PomodoroViewModel()
        let end = Date.now.addingTimeInterval(90)
        model.restore(.init(currentSession: 2, pomodoroStatus: "Focus", endDate: end,
                            stageDuration: 1500, remainingOnPause: nil))
        #expect(model.currentStage == 2)
        #expect(model.isTimerRunning)
        #expect(abs(model.remainingTime(at: end.addingTimeInterval(-60)) - 60) < 0.01)
        await model.pauseTimer()
        #expect(!model.isTimerRunning)
        #expect(model.hasActiveSession)
        #expect((85...90).contains(model.remainingTime(at: .now)))
        let paused = model.remainingTime(at: .now)
        #expect(model.remainingTime(at: .now.addingTimeInterval(600)) == paused)
    }

    @Test func restoresPausedIntervalWithoutStartingAnotherSession() async {
        let model = PomodoroViewModel()
        model.restore(.init(currentSession: 1, pomodoroStatus: "Interval", endDate: .now,
                            stageDuration: 300, remainingOnPause: 42))
        #expect(model.status == .rest)
        #expect(!model.isTimerRunning)
        #expect(model.remainingTime(at: .now.addingTimeInterval(600)) == 42)
        await model.restartPomodoro()
        #expect(!model.hasActiveSession)
        #expect(model.currentStage == 0)
        #expect(model.status == .focus)
    }

    @Test func expiredSessionAdvancesBeforeExternalResume() async {
        let model = PomodoroViewModel()
        model.restore(.init(currentSession: 0, pomodoroStatus: "Focus", endDate: .now.addingTimeInterval(-5),
                            stageDuration: 1500, remainingOnPause: nil))
        await model.advanceStage(at: .now)
        #expect(model.status == .rest)
        #expect(!model.isTimerRunning)
        #expect(model.remainingTime(at: .now) == 300)
    }

    @Test func intentPausesAndResumesTheMatchingLiveActivity() async throws {
        let state = MyTimePomodoroAttributes.ContentState(
            currentSession: 2, pomodoroStatus: "Focus", endDate: .now.addingTimeInterval(90),
            stageDuration: 1500, remainingOnPause: nil)
        let activity = try ActivityKit.Activity<MyTimePomodoroAttributes>.request(
            attributes: .init(), content: .init(state: state, staleDate: nil))
        do {
            let intent = PauseTimerIntent(activityID: activity.id)
            _ = try await intent.perform()
            #expect(!PomodoroViewModel.shared.isTimerRunning)
            #expect(PomodoroViewModel.shared.currentStage == 2)
            for _ in 0..<100 where activity.content.state.remainingOnPause == nil {
                try await Task.sleep(for: .milliseconds(20))
            }
            let paused = try #require(activity.content.state.remainingOnPause)
            #expect((0...90).contains(paused))

            _ = try await intent.perform()
            #expect(PomodoroViewModel.shared.isTimerRunning)
            for _ in 0..<100 where activity.content.state.remainingOnPause != nil {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(activity.content.state.remainingOnPause == nil)
            #expect(activity.content.state.endDate != nil)
            #expect(abs(PomodoroViewModel.shared.remainingTime(at: .now) - paused) < 2)
            await PomodoroViewModel.shared.restartPomodoro()
        } catch {
            await PomodoroViewModel.shared.restartPomodoro()
            await activity.end(nil, dismissalPolicy: .immediate)
            throw error
        }
    }

    @Test(arguments: [false, true])
    func intentHandlesExpiredActivity(finishingCycle: Bool) async throws {
        let state = MyTimePomodoroAttributes.ContentState(
            currentSession: finishingCycle ? 3 : 0,
            pomodoroStatus: finishingCycle ? "Long Interval" : "Focus",
            endDate: .now.addingTimeInterval(-5),
            stageDuration: finishingCycle ? 1800 : 1500, remainingOnPause: nil)
        let activity = try ActivityKit.Activity<MyTimePomodoroAttributes>.request(
            attributes: .init(), content: .init(state: state, staleDate: nil))
        do {
            _ = try await PauseTimerIntent(activityID: activity.id).perform()
            if finishingCycle {
                #expect(PomodoroViewModel.shared.status == .ended)
                #expect(!PomodoroViewModel.shared.isTimerRunning)
                #expect(activity.activityState == .ended || activity.activityState == .dismissed)
            } else {
                for _ in 0..<100 where activity.content.state.pomodoroStatus != "Interval" {
                    try await Task.sleep(for: .milliseconds(20))
                }
                #expect(activity.content.state.pomodoroStatus == "Interval")
                #expect(PomodoroViewModel.shared.isTimerRunning)
                #expect(activity.content.state.endDate != nil)
            }
            #expect(PomodoroViewModel.shared.currentStage == state.currentSession)
            await PomodoroViewModel.shared.restartPomodoro()
        } catch {
            await PomodoroViewModel.shared.restartPomodoro()
            await activity.end(nil, dismissalPolicy: .immediate)
            throw error
        }
    }

    @Test func restoresOnlyTheOwningTaskAndRoutesItsActivity() async throws {
        let container = try ModelContainer(for: Routine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let owner = MyTask(taskDescription: "Study")
        let other = MyTask(taskDescription: "Read")
        context.insert(owner)
        context.insert(other)
        try context.save()
        let model = PomodoroViewModel()
        await model.startSession(for: owner)
        let activity = try #require(ActivityKit.Activity<MyTimePomodoroAttributes>.activities.first {
            $0.attributes.taskID == owner.persistentModelID
        })
        do {
            // A fresh model represents a new app process recovering ActivityKit's session.
            let recovered = PomodoroViewModel(activity: activity)
            #expect(recovered.belongs(to: owner))
            #expect(!recovered.belongs(to: other))
            #expect(recovered.isTimerRunning)
            #expect(recovered.remainingTime(at: .now) > 1490)
            let url = try #require(MyTimePomodoroAttributes.url(activityID: activity.id))
            #expect(recovered.taskID(for: url) == owner.persistentModelID)
            #expect(recovered.taskID(for: URL(string: "mytime://pomodoro/unknown")!) == nil)
            #expect(recovered.taskID(for: URL(string: "other://pomodoro/\(activity.id)")!) == nil)
            await model.restartPomodoro()
        } catch {
            await model.restartPomodoro()
            throw error
        }
    }

    @Test func switchingTaskEndsPreviousActivityAndDeletedTaskEndsSession() async throws {
        let container = try ModelContainer(for: Routine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let first = MyTask(taskDescription: "Study")
        let second = MyTask(taskDescription: "Read")
        context.insert(first)
        context.insert(second)
        try context.save()
        let model = PomodoroViewModel()
        await model.startSession(for: first)
        let previous = try #require(ActivityKit.Activity<MyTimePomodoroAttributes>.activities.first {
            $0.attributes.taskID == first.persistentModelID
        })
        await model.startSession(for: second)
        #expect(model.belongs(to: second))
        #expect(!model.belongs(to: first))
        #expect(model.currentStage == 0)
        #expect(previous.activityState == .ended || previous.activityState == .dismissed)
        let current = try #require(ActivityKit.Activity<MyTimePomodoroAttributes>.activities.first {
            $0.attributes.taskID == second.persistentModelID
        })
        await model.reconcile(tasks: [first])
        #expect(!model.hasSession)
        #expect(!model.isTimerRunning)
        #expect(current.activityState == .ended || current.activityState == .dismissed)
    }

    @Test func intentWithAnUnknownActivityDoesNotChangeSession() async throws {
        let model = PomodoroViewModel.shared
        let previousStage = model.currentStage
        let previousStatus = model.status
        let wasRunning = model.isTimerRunning
        _ = try await PauseTimerIntent(activityID: UUID().uuidString).perform()
        #expect(model.currentStage == previousStage)
        #expect(model.status == previousStatus)
        #expect(model.isTimerRunning == wasRunning)
    }

    @Test func hobbyAndPomodoroSessionsAreMutuallyExclusive() async throws {
        let container = try ModelContainer(for: Routine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let task = MyTask(taskDescription: "Study")
        let first = Activity(hobby: Hobby(title: "Read", hobbyDescription: ""), durationInMin: 30)
        let second = Activity(hobby: Hobby(title: "Walk", hobbyDescription: ""), durationInMin: 15)
        container.mainContext.insert(Routine(activities: [Activity(task: task), first, second]))
        try container.mainContext.save()
        let pomodoro = PomodoroViewModel.shared
        let timer = TimerViewModel.shared
        defer { timer.restartTimer() }

        await pomodoro.startSession(for: task)
        #expect(pomodoro.isTimerRunning)
        await timer.startSession(for: first)
        #expect(!pomodoro.hasSession && !pomodoro.isTimerRunning)
        #expect(timer.belongs(to: first) && timer.isTimerRunning)
        let remaining = timer.remainingTime(at: .now)
        _ = TimerView(activity: first)
        _ = TimerView(activity: second)
        #expect(timer.belongs(to: first))
        #expect(abs(timer.remainingTime(at: .now) - remaining) < 1)

        await timer.startSession(for: second)
        #expect(!timer.belongs(to: first) && timer.belongs(to: second))
        #expect(timer.duration == 15 * 60)
        timer.pauseTimer()
        #expect(timer.isActive && !timer.isTimerRunning)
        await pomodoro.startSession(for: task)
        #expect(!timer.isActive && timer.activityID == nil)
        #expect(pomodoro.isTimerRunning)
        await timer.startSession(for: first)
        #expect(!pomodoro.hasSession)
        first.hobby = second.hobby
        #expect(!timer.belongs(to: first))
        timer.reconcile(activities: [first, second])
        #expect(!timer.isActive)
        await timer.startSession(for: first)
        timer.reconcile(activities: [second])
        #expect(!timer.isActive && timer.activityID == nil)
    }

    @Test func hobbySessionRestoresRunningAndPausedTime() async throws {
        let suiteName = "MyTimeTimerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let container = try ModelContainer(for: Routine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let activity = Activity(hobby: Hobby(title: "Read", hobbyDescription: ""), durationInMin: 30)
        container.mainContext.insert(Routine(activities: [activity]))
        try container.mainContext.save()
        let timer = TimerViewModel(duration: 0, defaults: defaults)
        defer { timer.restartTimer() }
        await timer.startSession(for: activity)
        let recovered = TimerViewModel(duration: 0, defaults: defaults)
        #expect(recovered.belongs(to: activity) && recovered.isTimerRunning)
        #expect(abs(recovered.remainingTime(at: .now) - timer.remainingTime(at: .now)) < 1)
        timer.pauseTimer()
        let paused = TimerViewModel(duration: 0, defaults: defaults)
        #expect(paused.belongs(to: activity) && paused.isActive && !paused.isTimerRunning)
        #expect(paused.remainingTime(at: .now.addingTimeInterval(600)) == timer.remainingTime(at: .now))
        timer.restartTimer()
        let stopped = TimerViewModel(duration: 0, defaults: defaults)
        #expect(stopped.activityID == nil && !stopped.isActive)
    }

}
