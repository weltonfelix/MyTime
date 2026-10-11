import Foundation
import SwiftData
import Testing
@testable import MyTime

@MainActor
struct HobbyRegenerationTests {
    @Test func onlySurvivingAdditionsToTodaysRoutineTriggerOffer() {
        let first = Hobby(title: "Ler", hobbyDescription: "")
        let second = Hobby(title: "Correr", hobbyDescription: "")
        let initial: Set = [first.persistentModelID]
        let current: Set = [first.persistentModelID, second.persistentModelID]
        #expect(HobbyRegeneration.shouldOffer(initial: initial, current: current, routineDate: .now))
        #expect(!HobbyRegeneration.shouldOffer(initial: initial, current: initial, routineDate: .now))
        first.title = "Edited"
        #expect(!HobbyRegeneration.shouldOffer(initial: initial, current: initial, routineDate: .now))
        #expect(!HobbyRegeneration.shouldOffer(initial: initial, current: current, routineDate: nil))
        #expect(!HobbyRegeneration.shouldOffer(initial: initial, current: current, routineDate: .distantPast))
        #expect(!HobbyRegeneration.shouldOffer(initial: current, current: current, routineDate: .now))
    }

    @Test func completionUsesIdentityAndSurvivesFailedSave() throws {
        let container = try ModelContainer(for: Routine.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let first = MyTask(taskDescription: "Same")
        let second = MyTask(taskDescription: "Same")
        let hobby = Hobby(title: "Reading", hobbyDescription: "")
        let newHobby = Hobby(title: "Running", hobbyDescription: "")
        for task in [first, second] { context.insert(task) }
        for item in [hobby, newHobby] { context.insert(item) }
        let a = Activity(task: first, isCompleted: true)
        let b = Activity(task: second)
        let c = Activity(hobby: hobby, durationInMin: 15)
        c.isCompleted = true
        context.insert(Routine(activities: [a, b, c]))
        try context.save()
        let draft = [PlannedActivity(task: first), PlannedActivity(task: second),
                     PlannedActivity(hobby: hobby, durationInMin: 15), PlannedActivity(hobby: newHobby, durationInMin: 15)]
        do {
            try RoutinePersistence.replace(with: draft, in: context, preserveCompletion: true, save: { _ in
                throw OnDeviceAI.Failure.invalidResponse
            })
            Issue.record("Save should fail")
        } catch {}
        #expect(a.isCompleted && c.isCompleted && !b.isCompleted)
        try RoutinePersistence.replace(with: draft, in: context, preserveCompletion: true)
        let activities = try context.fetch(FetchDescriptor<Routine>()).first!.activities
        #expect(activities.first { $0.task === first }?.isCompleted == true)
        #expect(activities.first { $0.task === second }?.isCompleted == false)
        #expect(activities.first { $0.hobby === hobby }?.isCompleted == true)
        #expect(activities.first { $0.hobby === newHobby }?.isCompleted == false)
        try RoutinePersistence.replace(with: draft, in: context)
        #expect(try context.fetch(FetchDescriptor<Routine>()).first!.activities.allSatisfy { !$0.isCompleted })
    }
}
