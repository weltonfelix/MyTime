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
    @Guide(description: "Task title exactly as provided")
    var title: String

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

@Generable(description: "Classification of all tasks")
struct ClassifiedTaskList {
    @Guide(description: "All tasks classified with type and estimated duration")
    var tasks: [ClassifiedTask]
}

struct MatchedTask {
    var task: MyTask
    let classification: ClassifiedTask?
}

class TaskClassifier {
    private let session: LanguageModelSession

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

    init() {
        session = LanguageModelSession(
            instructions: TaskClassifier.systemPrompt
        )
    }

    private func matchTask(
        _ classified: ClassifiedTask,
        in tasks: [(MyTask, String)]
    )
        -> MatchedTask?
    {
        let normalizedGenerated = classified.title.normalized

        return tasks.first {
            $0.1.normalized == normalizedGenerated
        }.map {
            MatchedTask(task: $0.0, classification: classified)
        }
    }

    private func insertMissingTasks(_ matched: [MatchedTask], tasks: [MyTask])
        -> [MatchedTask]
    {
        let matchedIDs = Set(matched.map(\.task.id))

        let missingTasks =
            tasks
            .filter { !matchedIDs.contains($0.id) }
            .map { MatchedTask(task: $0, classification: nil) }

        return matched + missingTasks
    }

    func classify(tasks: [MyTask]) async throws -> [MatchedTask] {
        let classificationPrompt = """
            Classify these tasks:
            \(tasks.map { "- \($0.taskDescription)" }.joined(separator: "\n"))
            """

        let response = try await session.respond(
            to: classificationPrompt,
            generating: ClassifiedTaskList.self,
        )

        let normalizedTasks = tasks.map({ ($0, $0.taskDescription.normalized) })

        let matchedTasks = response.content.tasks.compactMap { genTask in
            matchTask(genTask, in: normalizedTasks)
        }
        
        return insertMissingTasks(matchedTasks, tasks: tasks)
    }
}
