import Foundation
import SwiftData

enum SuggestedHobby: String, CaseIterable, Identifiable {
    case reading, walking, music, videoGames, drawing, cooking, meditation, instrument

    var id: Self { self }

    var title: String {
        String(localized: String.LocalizationValue(titleKey))
    }

    var hobbyDescription: String {
        String(localized: String.LocalizationValue(descriptionKey))
    }

    var symbol: String {
        switch self {
        case .reading: "book.closed.fill"
        case .walking: "figure.walk"
        case .music: "music.note"
        case .videoGames: "gamecontroller.fill"
        case .drawing: "pencil.tip.crop.circle"
        case .cooking: "fork.knife"
        case .meditation: "sparkles"
        case .instrument: "pianokeys"
        }
    }

    var energyLevel: HobbyEnergyLevel {
        switch self {
        case .reading, .music, .meditation: .low
        case .walking, .videoGames, .drawing, .cooking, .instrument: .medium
        }
    }

    var minimumDurationInMinutes: Int {
        switch self {
        case .reading, .walking, .drawing: 10
        case .music, .meditation: 5
        case .videoGames, .instrument: 15
        case .cooking: 30
        }
    }

    private var titleKey: String {
        switch self {
        case .reading: "Reading"
        case .walking: "Walking"
        case .music: "Listening to music"
        case .videoGames: "Playing video games"
        case .drawing: "Drawing"
        case .cooking: "Cooking"
        case .meditation: "Meditating"
        case .instrument: "Playing an instrument"
        }
    }

    private var descriptionKey: String {
        switch self {
        case .reading: "I like reading a little and getting into a good story."
        case .walking: "I like going for a walk to clear my head."
        case .music: "I like putting on my favorite music and just listening."
        case .videoGames: "I like playing video games for fun."
        case .drawing: "I like drawing and putting my ideas on paper."
        case .cooking: "I like cooking and trying out recipes."
        case .meditation: "I like taking a moment to breathe and meditate."
        case .instrument: "I like playing an instrument and practicing songs I enjoy."
        }
    }

    private var titleAliases: [String] {
        switch self {
        case .reading: ["Reading", "Ler"]
        case .walking: ["Walking", "Caminhar"]
        case .music: ["Listening to music", "Ouvir música"]
        case .videoGames: ["Playing video games", "Jogar videogame"]
        case .drawing: ["Drawing", "Desenhar"]
        case .cooking: ["Cooking", "Cozinhar"]
        case .meditation: ["Meditating", "Meditar"]
        case .instrument: ["Playing an instrument", "Tocar instrumento"]
        }
    }

    @MainActor
    static func persist(
        _ selected: Set<SuggestedHobby>,
        in context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        guard !selected.isEmpty else { return }
        let existingTitles = try context.fetch(FetchDescriptor<Hobby>()).map { $0.title.normalized }
        let additions = allCases.filter { selected.contains($0) && Set($0.titleAliases.map(\.normalized)).isDisjoint(with: existingTitles) }
            .map { suggestion in
                let hobby = Hobby(title: suggestion.title, hobbyDescription: suggestion.hobbyDescription)
                hobby.energyLevel = suggestion.energyLevel
                hobby.minimumDurationInMinutes = suggestion.minimumDurationInMinutes
                return hobby
            }
        guard !additions.isEmpty else { return }

        for addition in additions {
            context.insert(addition)
        }
        do {
            try save(context)
        } catch {
            for addition in additions {
                context.delete(addition)
            }
            throw error
        }
    }
}
