//
//  TaskClassificator.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation
import FoundationModels

@Generable(description: "Task classification")
struct ClassifiedTask {
    @Guide(description: "Classification of the activity")
    var activityType: TaskActivityType

    @Guide(
        description: "Estimated time in minutes needed to complete the task",
        .range(15...180)
    )
    var estimatedDuration: Int
}

@Generable
enum TaskActivityType: String {
    case cognitiveHeavy
    case cognitiveMedium
    case cognitiveLight
    case physical
    case domestic
}

struct MatchedTask {
    var task: MyTask
    let classification: ClassifiedTask?
}

class TaskClassifier {
    private static let systemPrompt = """
        You are a task classifier. For each task provided, classify it and estimate duration.

            Activity types:
            - cognitiveHeavy: studying, technical reading, programming, complex analysis
            - cognitiveMedium: emails, planning, meetings, writing
            - cognitiveLight: simple admin tasks, form filling, quick reviews
            - physical: gym, running, sports, physical exercise
            - domestic: cleaning, cooking, organizing, errands

            Estimate duration based on the specific task.
        """

    func classify(tasks: [MyTask], infer: (String) async throws -> ClassifiedTask = TaskClassifier.infer) async throws -> [MatchedTask] {
        let inputs = tasks.map { ($0, $0.taskDescription) }
        var result: [MatchedTask] = []
        for (task, description) in inputs {
            try Task.checkCancellation()
            let classification = try await infer(description)
            try Self.validate(classification)
            result.append(MatchedTask(task: task, classification: classification))
        }
        return result
    }

    private static func infer(_ description: String) async throws -> ClassifiedTask {
        try OnDeviceAI.checkAvailability()
        let session = LanguageModelSession(instructions: systemPrompt + OnDeviceAI.inputInstructions)
        return try await session.respond(
            to: OnDeviceAI.encodeInput(["task": description]), generating: ClassifiedTask.self,
            options: GenerationOptions(samplingMode: .greedy)
        ).content
    }

    static func validate(_ classification: ClassifiedTask) throws {
        guard (15...180).contains(classification.estimatedDuration) else {
            throw OnDeviceAI.Failure.invalidResponse
        }
    }
}
