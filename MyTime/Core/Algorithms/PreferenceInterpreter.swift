import Foundation
import FoundationModels

struct InterpretedPreferences {
    enum HobbyAmount { case fewer, normal, more, none }
    enum AvailableTime { case less, normal, more }

    var hobbies: HobbyAmount
    var availableTime: AvailableTime
    var preferLowEnergy: Bool
    var preferShortSessions: Bool
    var hasUnsupportedRequests: Bool

    var adjustments: UserInstructionsParser.Adjustments {
        var result = UserInstructionsParser.Adjustments()
        switch hobbies {
        case .fewer: result.maxFactorDelta = -0.15
        case .more: result.maxFactorDelta = 0.15
        case .none: result.excludeHobbies = true
        case .normal: break
        }
        switch availableTime {
        case .less: result.availableMinutesDelta = -120
        case .more: result.availableMinutesDelta = 120
        case .normal: break
        }
        result.preferLowEnergy = preferLowEnergy
        result.preferShortSessions = preferShortSessions
        return result
    }
}

@Generable
struct ExtractedPreferences {
    @Generable
    enum Tag: String, Hashable {
        case neutral
        case fewerHobbies, moreHobbies, noHobbies
        case lessAvailableTime, moreAvailableTime
        case lowEnergy, shortHobbySessions
        case exactSchedule, deadline, specificActivityOrder, exactTimeBudget
    }

    @Guide(description: "Only preferences explicitly expressed by the user. No tags for negated or unspecified preferences. Use only neutral if none apply.", .count(1...12))
    var preferences: [Tag]

    var interpreted: InterpretedPreferences {
        let tags = Set(preferences)
        let quantities = tags.intersection([.fewerHobbies, .moreHobbies, .noHobbies])
        let hobbyAmount: InterpretedPreferences.HobbyAmount
        if quantities.count == 1 {
            switch quantities.first {
            case .fewerHobbies: hobbyAmount = .fewer
            case .moreHobbies: hobbyAmount = .more
            case .noHobbies: hobbyAmount = .none
            default: hobbyAmount = .normal
            }
        } else {
            hobbyAmount = .normal
        }
        let time: InterpretedPreferences.AvailableTime
        if tags.contains(.lessAvailableTime) && !tags.contains(.moreAvailableTime) {
            time = .less
        } else if tags.contains(.moreAvailableTime) && !tags.contains(.lessAvailableTime) {
            time = .more
        } else {
            time = .normal
        }
        return InterpretedPreferences(hobbies: hobbyAmount, availableTime: time,
            preferLowEnergy: tags.contains(.lowEnergy), preferShortSessions: tags.contains(.shortHobbySessions),
            hasUnsupportedRequests: !tags.isDisjoint(with: [.exactSchedule, .deadline, .specificActivityOrder, .exactTimeBudget]))
    }
}

enum PreferenceInterpreter {
    private static let instructions = """
        Extract ONLY explicitly stated preferences in English or Portuguese as tags.
        A missing, negated, or unclear preference has no tag. Return [neutral] when none apply.
        fewerHobbies/moreHobbies/noHobbies: explicit hobby quantity or frequency.
        lessAvailableTime: busy day or little free time. moreAvailableTime: plenty of free time.
        lowEnergy: explicitly tired or wanting low-energy activities.
        shortHobbySessions: explicitly short hobbies or breaks.
        exactSchedule: explicitly requested clock times; deadline: a requested deadline.
        specificActivityOrder: explicitly requested order; exactTimeBudget: an exact numeric time budget.
        Never infer quantity or available time from energy or session duration.
        Never infer energy or session duration from available time.
        Examples of complete tag lists:
        "Hello" -> [neutral]
        "Não estou cansado e não quero pausas curtas" -> [neutral]
        "Sem hobbies" -> [noHobbies]
        "I'm tired; keep hobbies short" -> [lowEnergy, shortHobbySessions]
        "Hoje será um dia corrido, quero menos hobbies" -> [lessAvailableTime, fewerHobbies]
        "I have plenty of free time; include more hobbies" -> [moreAvailableTime, moreHobbies]
        "Schedule studying at 09:00 and use short hobby sessions" -> [exactSchedule, shortHobbySessions]
        Include both quantity/time tags if explicitly conflicting; the app resolves them.
        """

    static func interpret(_ text: String) async throws -> InterpretedPreferences {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ExtractedPreferences(preferences: [.neutral]).interpreted
        }
        try Task.checkCancellation()
        try OnDeviceAI.checkAvailability()
        // Explicit tags avoid correlated defaults; Swift resolves contradictions and fills neutral values.
        let session = LanguageModelSession(instructions: instructions + OnDeviceAI.inputInstructions)
        let response = try await session.respond(
            to: OnDeviceAI.encodeInput(["preferences": text]), generating: ExtractedPreferences.self,
            options: GenerationOptions(samplingMode: .greedy)
        )
        guard (1...12).contains(response.content.preferences.count) else { throw OnDeviceAI.Failure.invalidResponse }
        return response.content.interpreted
    }
}
