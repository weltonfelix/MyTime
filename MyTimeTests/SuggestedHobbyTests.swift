import SwiftData
import Testing
@testable import MyTime

@MainActor
struct SuggestedHobbyTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Routine.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func persistsSelectedHobbiesAndSkipsEnglishAndPortugueseDuplicates() throws {
        let modelContainer = try container()
        let context = modelContainer.mainContext
        context.insert(Hobby(title: "Reading", hobbyDescription: "Existing"))
        context.insert(Hobby(title: "Caminhar", hobbyDescription: "Existing"))
        try context.save()

        try SuggestedHobby.persist([.reading, .walking, .cooking], in: context)
        var hobbies = try context.fetch(FetchDescriptor<Hobby>())
        #expect(hobbies.count == 3)
        let cooking = try #require(hobbies.first { ["Cooking", "Cozinhar"].contains($0.title) })
        #expect(cooking.minimumDurationInMinutes == 30)
        #expect(cooking.energyLevel == .medium)
        #expect(!cooking.hobbyDescription.isEmpty)

        try SuggestedHobby.persist([.reading, .walking, .cooking], in: context)
        hobbies = try context.fetch(FetchDescriptor<Hobby>())
        #expect(hobbies.count == 3)
    }

    @Test func emptySelectionDoesNotSave() throws {
        let modelContainer = try container()
        let context = modelContainer.mainContext
        var didSave = false
        try SuggestedHobby.persist([], in: context) { _ in didSave = true }
        #expect(!didSave)
        #expect(try context.fetchCount(FetchDescriptor<Hobby>()) == 0)
    }

    @Test func failedSaveRemovesOnlyNewHobbiesAndCanBeRetried() throws {
        let modelContainer = try container()
        let context = modelContainer.mainContext
        let existing = Hobby(title: "My own hobby", hobbyDescription: "Keep this")
        context.insert(existing)
        try context.save()

        enum InjectedFailure: Error { case save }
        #expect(throws: InjectedFailure.self) {
            try SuggestedHobby.persist([.reading, .cooking], in: context) { _ in
                throw InjectedFailure.save
            }
        }
        #expect(try context.fetchCount(FetchDescriptor<Hobby>()) == 1)
        #expect(existing.hobbyDescription == "Keep this")

        try SuggestedHobby.persist([.reading, .cooking], in: context)
        #expect(try context.fetchCount(FetchDescriptor<Hobby>()) == 3)
    }

    @Test func suggestionsHaveExpectedEnergyAndDurations() {
        #expect(SuggestedHobby.reading.energyLevel == .low && SuggestedHobby.reading.minimumDurationInMinutes == 10)
        #expect(SuggestedHobby.walking.energyLevel == .medium && SuggestedHobby.walking.minimumDurationInMinutes == 10)
        #expect(SuggestedHobby.music.energyLevel == .low && SuggestedHobby.music.minimumDurationInMinutes == 5)
        #expect(SuggestedHobby.videoGames.energyLevel == .medium && SuggestedHobby.videoGames.minimumDurationInMinutes == 15)
        #expect(SuggestedHobby.drawing.energyLevel == .medium && SuggestedHobby.drawing.minimumDurationInMinutes == 10)
        #expect(SuggestedHobby.cooking.energyLevel == .medium && SuggestedHobby.cooking.minimumDurationInMinutes == 30)
        #expect(SuggestedHobby.meditation.energyLevel == .low && SuggestedHobby.meditation.minimumDurationInMinutes == 5)
        #expect(SuggestedHobby.instrument.energyLevel == .medium && SuggestedHobby.instrument.minimumDurationInMinutes == 15)
    }
}
