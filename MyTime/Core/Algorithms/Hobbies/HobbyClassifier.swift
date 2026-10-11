//
//  HobbyClassificator.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation
import FoundationModels
import SwiftData

@Generable(description: "Hobby classification")
struct ClassifiedHobby {
    @Guide(description: "Physical or mental energy required to do this hobby")
    var energyLevel: GenerableEnergyLevel

    @Guide(
        description:
            "Minimum meaningful duration in minutes — below this the hobby isn't worth doing",
        .range(1...720)
    )
    var minimumDurationInMinutes: Int


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

    func classify(hobby: Hobby) async throws {
        let title = hobby.title
        let description = hobby.hobbyDescription
        try OnDeviceAI.checkAvailability()
        let session = LanguageModelSession(instructions: Self.systemPrompt + OnDeviceAI.inputInstructions)
        let response = try await session.respond(
            to: OnDeviceAI.encodeInput(["title": title, "description": description]),
            generating: ClassifiedHobby.self,
            options: GenerationOptions(samplingMode: .greedy)
        )
        try Self.validate(response.content)
        try Task.checkCancellation()
        Self.apply(response.content, to: hobby, title: title, description: description)
    }

    static func apply(_ classification: ClassifiedHobby, to hobby: Hobby, title: String, description: String) {
        guard !hobby.isDeleted, hobby.modelContext != nil,
              hobby.title == title, hobby.hobbyDescription == description else { return }
        hobby.energyLevel = classification.energyLevel.asHobbyEnergyLevel
        hobby.minimumDurationInMinutes = classification.minimumDurationInMinutes
    }

    static func validate(_ classification: ClassifiedHobby) throws {
        guard (1...720).contains(classification.minimumDurationInMinutes) else {
            throw OnDeviceAI.Failure.invalidResponse
        }
    }
}
