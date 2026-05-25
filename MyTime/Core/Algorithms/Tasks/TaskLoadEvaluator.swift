//
//  TaskLoadEvaluator.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation

class TaskLoadEvaluator {
    private let heavyTaskWeight = 1.0
    private let mediumTaskWeight = 0.5

    /**
         Calculates a normalized score (0-1) for a set of tasks using a custom weight function.
         Used as a base for cognitive and physical scoring.

         - Parameter tasks: the tasks to score
         - Parameter weight: the weight function to evaluate the tasks

         - Returns: A score between 0 and 1
     */
    private func taskScore(
        tasks: [MatchedTask],
        weight: (TaskActivityType?) -> Double
    ) -> Double {
        let base = tasks.reduce(0) {
            $0 + weight($1.classification?.activityType)
        }
        return base / Double(tasks.count)
    }

    /**
        Calculates a score reflecting the cognitive load of the day.
        Heavy tasks contribute more than medium ones.

        - Parameter tasks: the tasks to score

        - Returns: A score between 0 and 1
     */
    func cognitiveScore(tasks: [MatchedTask]) -> Double {
        taskScore(tasks: tasks) { type in
            switch type {
            case .cognitiveHeavy: heavyTaskWeight
            case .cognitiveMedium: mediumTaskWeight
            default: 0
            }
        }
    }

    /**
        Calculates a score reflecting the physical load of the day.

        - Parameter tasks: the tasks to score

        - Returns: A score between 0 and 1
     */
    func physicalScore(tasks: [MatchedTask]) -> Double {
        taskScore(tasks: tasks) { $0 == .physical ? 1.0 : 0.0 }
    }
    
    static func isHeavy(task: MatchedTask) -> Bool {
        return task.classification?.activityType == .cognitiveHeavy
    }
}
