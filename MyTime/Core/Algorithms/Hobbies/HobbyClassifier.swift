//
//  HobbyClassificator.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation
import FoundationModels
import Playgrounds

@Generable(description: "Hobby classification")
struct ClassifiedHobby {
    @Guide(description: "Physical or mental energy required to do this hobby")
    var energyLevel: GenerableEnergyLevel

    @Guide(
        description:
            "Minimum meaningful duration in minutes — below this the hobby isn't worth doing"
    )
    var minimumDurationInMinutes: Int

    //    @Guide(
    //        description: "Estimated typical duration in minutes based on the hobby"
    //    )
    //    var estimatedDuration: Int
}

@Generable
enum GenerableEnergyLevel: String {
    case high
    case medium
    case low

    var asHobbyEnergyLevel: HobbyEnergyLevel {
        HobbyEnergyLevel(rawValue: rawValue)!
    }
}

class HobbyClassifier {
    private let session: LanguageModelSession

    private static let systemPrompt = """
            You are a hobby classifier. For the provided hobby, analyze its
            title and description, classify it and estimate durations.

            You will receive the hobby title and its description.
            
            Examples:
            Energy levels:
            - high: swimming, sports, dancing, intense physical activity
            - medium: cooking, board games, playing instruments, crafts
            - low: watching TV, casual reading, meditation, relaxing activities

            Minimum Duration in Minutes:
            - tocar instrumentos - 15
            - fazer pão - 60
            - watching movies - 90
            - assistir séries - 25
            - running - 45

            Estimate realistic durations based on what the hobby actually involves.
            minimumDuration should be the shortest time the hobby is still meaningful.
        """

    init() {
        session = LanguageModelSession(
            instructions: HobbyClassifier.systemPrompt
        )
    }

    func classify(hobby: Hobby) async throws {
        let classificationPrompt = """
            Classify this hobby:
            - \(hobby.title) \(hobby.hobbyDescription.isEmpty ? "" : ": \(hobby.hobbyDescription)")
            """

        let response = try await session.respond(
            to: classificationPrompt,
            generating: ClassifiedHobby.self,
        )

        hobby.energyLevel =
            response.content.energyLevel.asHobbyEnergyLevel
        hobby.minimumDurationInMinutes =
            response.content.minimumDurationInMinutes
    }
}

#Playground {
    let classifier = HobbyClassifier()
    let hobbies = [
        Hobby(
            title: "Cozinhar",
            hobbyDescription:
                "Leva a tarde inteira, preciso de bastante tempo livre."
        ),
        Hobby(
            title: "Assistir séries",
            hobbyDescription:
                "Gosto de assistir quando tenho algum tempo livre."
        ),
    ]
    do {
        try await classifier.classify(hobby: hobbies[1])
    } catch {
        print(error)
    }
}
