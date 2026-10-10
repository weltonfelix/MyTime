import Foundation
import FoundationModels
import SwiftData
import Testing
@testable import MyTime

@MainActor
struct RoutineTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Routine.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func preferenceMapping() {
        let fewer = InterpretedPreferences(hobbies: .fewer, availableTime: .less,
            preferLowEnergy: true, preferShortSessions: true, hasUnsupportedRequests: false).adjustments
        #expect(fewer.maxFactorDelta == -0.15)
        #expect(fewer.availableMinutesDelta == -120)
        #expect(fewer.preferLowEnergy && fewer.preferShortSessions)
        let more = InterpretedPreferences(hobbies: .more, availableTime: .more,
            preferLowEnergy: false, preferShortSessions: false, hasUnsupportedRequests: false).adjustments
        #expect(more.maxFactorDelta == 0.15 && more.availableMinutesDelta == 120)
        let none = InterpretedPreferences(hobbies: .none, availableTime: .normal,
            preferLowEnergy: false, preferShortSessions: false, hasUnsupportedRequests: true).adjustments
        #expect(none.excludeHobbies)
    }

    @Test func extractedTagsResolveConflictsAndDefaults() {
        let neutral = ExtractedPreferences(preferences: [.neutral]).interpreted
        #expect(neutral.adjustments == UserInstructionsParser.Adjustments())
        let conflict = ExtractedPreferences(preferences: [.fewerHobbies, .moreHobbies, .lessAvailableTime, .moreAvailableTime]).interpreted
        #expect(conflict.hobbies == .normal && conflict.availableTime == .normal)
        let duplicate = ExtractedPreferences(preferences: [.noHobbies, .noHobbies, .neutral]).interpreted
        #expect(duplicate.adjustments.excludeHobbies)
        let independent = ExtractedPreferences(preferences: [.lowEnergy, .shortHobbySessions]).interpreted
        #expect(independent.hobbies == .normal && independent.availableTime == .normal)
        #expect(independent.preferLowEnergy && independent.preferShortSessions)
        #expect(!independent.hasUnsupportedRequests)
        for tag in [ExtractedPreferences.Tag.exactSchedule, .deadline, .specificActivityOrder, .exactTimeBudget] {
            #expect(ExtractedPreferences(preferences: [tag]).interpreted.hasUnsupportedRequests)
        }
    }

    @Test func emptyPreferencesNeedNoModel() async throws {
        let result = try await PreferenceInterpreter.interpret(" \n ")
        #expect(result.adjustments == UserInstructionsParser.Adjustments())
        #expect(!result.hasUnsupportedRequests)
    }

    @Test func identicalDescriptionsStaySeparate() async throws {
        let first = MyTask(taskDescription: "Study")
        let second = MyTask(taskDescription: "Study")
        var calls = 0
        let result = try await TaskClassifier().classify(tasks: [first, second]) { input in
            #expect(input == "Study")
            calls += 1
            return ClassifiedTask(activityType: .cognitiveHeavy, estimatedDuration: calls * 15)
        }
        #expect(result.count == 2 && calls == 2)
        #expect(result[0].task === first && result[1].task === second)
        #expect(result[0].classification?.estimatedDuration == 15)
        #expect(result[1].classification?.estimatedDuration == 30)
        let empty = try await TaskClassifier().classify(tasks: []) { _ in
            Issue.record("Empty tasks must not call the model")
            return ClassifiedTask(activityType: .domestic, estimatedDuration: 15)
        }
        #expect(empty.isEmpty)
    }

    @Test func invalidResponsesAreRejected() {
        #expect(throws: (any Error).self) {
            try TaskClassifier.validate(ClassifiedTask(activityType: .physical, estimatedDuration: 0))
        }
        for duration in [0, -1, 721] {
            #expect(throws: (any Error).self) {
                try HobbyClassifier.validate(ClassifiedHobby(energyLevel: .low, minimumDurationInMinutes: duration))
            }
        }
    }

    @Test func modelErrorsHaveActionableMessages() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
        let oldError = LanguageModelSession.GenerationError.exceededContextWindowSize(context)
        let expected = String(localized: "This text is too long for the on-device model. Shorten it or generate a basic routine.")
        #expect(OnDeviceAI.message(for: oldError) == expected)
        let bridged = NSError(domain: "FoundationModels.LanguageModelSession.GenerationError", code: -1)
        #expect(OnDeviceAI.message(for: bridged) == OnDeviceAI.Failure.invalidResponse.localizedDescription)
        if #available(iOS 27.0, *) {
            let newError = LanguageModelError.contextSizeExceeded(.init(contextSize: 4096,
                tokenCount: 5000, debugDescription: "test"))
            #expect(OnDeviceAI.message(for: newError) == expected)
            #expect(OnDeviceAI.message(for: LanguageModelSession.Error.concurrentRequests)
                == String(localized: "The on-device model is busy. Please try again shortly."))
        }
    }

    @Test func emptyAndExhaustedBudgets() throws {
        #expect(TaskLoadEvaluator().cognitiveScore(tasks: []) == 0)
        #expect(TaskLoadEvaluator().physicalScore(tasks: []) == 0)
        #expect(try RoutineGenerator().generate(tasks: [], hobbies: []).isEmpty)
        let task = MyTask(taskDescription: "Work")
        let hobby = Hobby(title: "Read", hobbyDescription: "")
        let selector = HobbySelector(config: .init(availableDayMinutes: 30))
        #expect(selector.select(tasks: [MatchedTask(task: task, classification: nil)], hobbies: [hobby]).isEmpty)
    }

    @Test func budgetsAndShortSessions() {
        let hobbies = (1...4).map { index in
            let hobby = Hobby(title: "Hobby \(index)", hobbyDescription: "")
            hobby.minimumDurationInMinutes = 7 + index
            return hobby
        }
        for budget in 1...150 {
            let config = HobbySelectorConfiguration(availableDayMinutes: budget)
            let selected = HobbySelector(config: config).select(tasks: [], hobbies: hobbies)
            #expect(selected.reduce(0) { $0 + $1.durationInMinutes } <= Int(Double(budget) * config.lightCognitiveFactor))
            #expect(selected.allSatisfy { $0.durationInMinutes >= ($0.hobby.minimumDurationInMinutes ?? 15) })
        }
        var preferences = UserInstructionsParser.Adjustments()
        preferences.preferShortSessions = true
        let short = HobbySelector(config: .init(adjustments: preferences)).select(tasks: [], hobbies: hobbies)
        #expect(!short.isEmpty)
        #expect(short.allSatisfy { $0.durationInMinutes == $0.hobby.minimumDurationInMinutes })
        preferences.excludeHobbies = true
        #expect(HobbySelector(config: .init(adjustments: preferences)).select(tasks: [], hobbies: hobbies).isEmpty)
    }

    @Test func draftValidationAndNoRelationshipMutation() throws {
        let container = try container()
        let context = container.mainContext
        let task = MyTask(taskDescription: "Study")
        context.insert(task)
        let old = Activity(task: task)
        context.insert(Routine(activities: [old]))
        try context.save()
        let draft = try RoutineGenerator().generate(tasks: [MatchedTask(task: task, classification: nil)], hobbies: [])
        #expect(task.activity === old)
        #expect(draft.count == 1)
        #expect(throws: (any Error).self) { try PlannedActivity.validate(draft + draft, tasks: [task], hobbies: []) }
        #expect(throws: (any Error).self) { try PlannedActivity.validate([], tasks: [task], hobbies: []) }
        #expect(throws: (any Error).self) {
            try PlannedActivity.validate(draft + [PlannedActivity(hobby: Hobby(title: "Unknown", hobbyDescription: ""), durationInMin: 15)], tasks: [task], hobbies: [])
        }
    }

    @Test func snapshotDetectsChangesAndDeletion() throws {
        let task = MyTask(taskDescription: "Study")
        let hobby = Hobby(title: "Read", hobbyDescription: "")
        let original = RoutineSnapshot(tasks: [task], hobbies: [hobby], instructions: "")
        #expect(original == RoutineSnapshot(tasks: [task], hobbies: [hobby], instructions: ""))
        task.taskDescription = "Run"
        #expect(original != RoutineSnapshot(tasks: [task], hobbies: [hobby], instructions: ""))
        task.taskDescription = "Study"
        #expect(original != RoutineSnapshot(tasks: [], hobbies: [hobby], instructions: ""))
        #expect(original != RoutineSnapshot(tasks: [task], hobbies: [hobby], instructions: "short"))
        hobby.minimumDurationInMinutes = 20
        #expect(original != RoutineSnapshot(tasks: [task], hobbies: [hobby], instructions: ""))
    }

    @Test func hobbyEditsRejectStaleClassification() throws {
        let container = try container()
        let context = container.mainContext
        let hobby = Hobby(title: "Read", hobbyDescription: "Books")
        context.insert(hobby)
        try context.save()
        let result = ClassifiedHobby(energyLevel: .low, minimumDurationInMinutes: 15)
        hobby.hobbyDescription = "Long novels"
        HobbyClassifier.apply(result, to: hobby, title: "Read", description: "Books")
        #expect(hobby.minimumDurationInMinutes == nil)
        HobbyClassifier.apply(result, to: hobby, title: "Read", description: "Long novels")
        #expect(hobby.minimumDurationInMinutes == 15)
        context.delete(hobby)
        HobbyClassifier.apply(ClassifiedHobby(energyLevel: .high, minimumDurationInMinutes: 90),
                              to: hobby, title: "Read", description: "Long novels")
        #expect(hobby.minimumDurationInMinutes == 15)
    }

    @Test func replacementAndRollbackPreserveSources() throws {
        let container = try container()
        let context = container.mainContext
        let task = MyTask(taskDescription: "Study")
        let hobby = Hobby(title: "Read", hobbyDescription: "")
        context.insert(task)
        context.insert(hobby)
        let old = Routine(activities: [Activity(task: task), Activity(hobby: hobby, durationInMin: 15)])
        context.insert(old)
        try context.save()
        let oldID = old.persistentModelID
        let draft = [PlannedActivity(task: task), PlannedActivity(hobby: hobby, durationInMin: 20)]
        enum SaveFailure: Error { case injected }
        #expect(throws: SaveFailure.self) {
            try RoutinePersistence.replace(with: draft, in: context) { _ in throw SaveFailure.injected }
        }
        let restored = try #require(context.fetch(FetchDescriptor<Routine>()).first)
        #expect(restored.persistentModelID == oldID)
        #expect(restored.activities.count == 2)
        #expect(task.activity?.routine?.persistentModelID == oldID)
        #expect(hobby.activities.count == 1)
        // Simulate autosave after rollback and verify the actual store from a fresh context.
        try context.save()
        let verification = ModelContext(container)
        let savedOld = try #require(verification.fetch(FetchDescriptor<Routine>()).first)
        #expect(savedOld.persistentModelID == oldID)
        #expect(savedOld.activities.count == 2)
        #expect(try verification.fetchCount(FetchDescriptor<Activity>()) == 2)
        try RoutinePersistence.replace(with: draft, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Activity>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<MyTask>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Hobby>()) == 1)
        #expect(task.activity?.routine?.persistentModelID != oldID)
    }
}
