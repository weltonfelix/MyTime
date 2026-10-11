import Foundation
import SwiftData
import Testing
@testable import MyTime

@MainActor
struct DailyRolloverTests {
    @Test func removesExpiredRoutineAndCompletedTasksButKeepsPendingTasksAndHobbies() throws {
        let container = try ModelContainer(for: Routine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let pending = MyTask(taskDescription: "Finish tomorrow")
        let completed = MyTask(taskDescription: "Done")
        let unscheduled = MyTask(taskDescription: "Not scheduled yet")
        let hobby = Hobby(title: "Read", hobbyDescription: "")
        context.insert(unscheduled)
        let old = Routine(activities: [Activity(task: pending), Activity(task: completed, isCompleted: true),
            Activity(hobby: hobby, durationInMin: 15)])
        old.date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(old)
        try context.save()
        let pendingID = pending.persistentModelID

        #expect(try RoutinePersistence.removeExpired(in: context))
        let verification = ModelContext(container)
        let tasks = try verification.fetch(FetchDescriptor<MyTask>())
        #expect(Set(tasks.map(\.taskDescription)) == ["Finish tomorrow", "Not scheduled yet"])
        #expect(tasks.first { $0.persistentModelID == pendingID }?.activity == nil)
        #expect(try verification.fetchCount(FetchDescriptor<Routine>()) == 0)
        #expect(try verification.fetchCount(FetchDescriptor<Activity>()) == 0)
        #expect(try verification.fetchCount(FetchDescriptor<Hobby>()) == 1)
        let draft = try context.fetch(FetchDescriptor<MyTask>()).map { PlannedActivity(task: $0) }
        try RoutinePersistence.replace(with: draft, in: context)
        #expect(try !RoutinePersistence.removeExpired(in: context))
        #expect(try context.fetchCount(FetchDescriptor<MyTask>()) == 2)
    }
}
