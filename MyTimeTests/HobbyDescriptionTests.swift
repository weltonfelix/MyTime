import Foundation
import SwiftData
import Testing
@testable import MyTime

@MainActor
struct HobbyDescriptionTests {
    @Test func descriptionsMustMatchRequestedLanguage() throws {
        let portuguese = "Leitura de livros, contos ou outros textos."
        let english = "Reading books, short stories, or other written texts."
        try HobbyDescriptionGenerator.validate(portuguese, language: "pt-BR")
        try HobbyDescriptionGenerator.validate(english, language: "en")
        try HobbyDescriptionGenerator.validate("", language: "pt-BR")
        #expect(throws: OnDeviceAI.Failure.self) {
            try HobbyDescriptionGenerator.validate(english, language: "pt-BR")
        }
        #expect(throws: OnDeviceAI.Failure.self) {
            try HobbyDescriptionGenerator.validate(portuguese, language: "en")
        }
        #expect(throws: OnDeviceAI.Failure.self) {
            try HobbyDescriptionGenerator.validate(String(repeating: "a", count: 501), language: "en")
        }
    }

    @Test func suggestionPrecedesClassificationAndPreservesEdits() async throws {
        let container = try ModelContainer(for: Routine.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let hobby = Hobby(title: "Ler", hobbyDescription: "")
        container.mainContext.insert(hobby)
        let generator = HobbyDescriptionGenerator()
        await generator.prepare(hobby, suggest: { title, language in
            #expect(title == "Ler")
            #expect(language == Bundle.main.preferredLocalizations.first ?? "en")
            #expect(generator.pending.contains(hobby.persistentModelID))
            return "Leitura de textos."
        }, classify: { item in
            #expect(item.hobbyDescription == "Leitura de textos.")
        }, onError: { _ in Issue.record("Unexpected failure") })
        #expect(generator.pending.isEmpty)
        HobbyDescriptionGenerator.apply("Replacement", to: hobby, originalTitle: "Ler")
        #expect(hobby.hobbyDescription == "Leitura de textos.")
        hobby.hobbyDescription = ""
        hobby.title = "Correr"
        HobbyDescriptionGenerator.apply("Stale", to: hobby, originalTitle: "Ler")
        #expect(hobby.hobbyDescription.isEmpty)
        container.mainContext.delete(hobby)
        HobbyDescriptionGenerator.apply("Deleted", to: hobby, originalTitle: "Correr")
        #expect(hobby.hobbyDescription.isEmpty)
    }

    @Test func editsDuringRequestsArePreservedAndReclassified() async throws {
        let container = try ModelContainer(for: Routine.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let hobby = Hobby(title: "Ler", hobbyDescription: "")
        container.mainContext.insert(hobby)
        var calls = 0
        await HobbyDescriptionGenerator().prepare(hobby, suggest: { _, _ in
            hobby.hobbyDescription = "Minha descrição"
            return "Sugestão"
        }, classify: { item in
            calls += 1
            if calls == 1 {
                #expect(item.hobbyDescription == "Minha descrição")
                item.hobbyDescription = "Edição durante classificação"
            } else {
                #expect(item.hobbyDescription == "Edição durante classificação")
            }
        }, onError: { _ in Issue.record("Unexpected failure") })
        #expect(calls == 2)
    }

    @Test func failuresAndEmptySuggestionsKeepHobby() async throws {
        let container = try ModelContainer(for: Routine.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let hobby = Hobby(title: "Unknown", hobbyDescription: "")
        container.mainContext.insert(hobby)
        let generator = HobbyDescriptionGenerator()
        var classified = false
        var reported = false
        await generator.prepare(hobby, suggest: { _, _ in throw OnDeviceAI.Failure.invalidResponse }, classify: { _ in
            classified = true
        }, onError: { _ in reported = true })
        #expect(classified && reported && hobby.hobbyDescription.isEmpty)
        await generator.prepare(hobby, suggest: { _, _ in "" }, classify: { _ in }, onError: { _ in Issue.record("Empty is valid") })
        #expect(hobby.hobbyDescription.isEmpty)
        await generator.prepare(hobby, suggest: { _, _ in "Description" }, classify: { _ in
            throw OnDeviceAI.Failure.invalidResponse
        }, onError: { _ in })
        #expect(hobby.hobbyDescription == "Description")
    }
}
