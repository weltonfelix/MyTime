//
//  RoutineGenerator.swift
//  MyTime
//
//  Created by Welton Felix on 23/05/26.
//

import Foundation
import Playgrounds

/// Orders tasks and interleaves hobbies into a daily routine.
///
/// Task ordering rules:
/// - Physical tasks come first (morning)
/// - cognitiveHeavy tasks are never consecutive
/// - domestic and cognitiveLight act as buffers between heavy tasks
/// - cognitiveMedium fills the middle
///
/// Hobby insertion rules:
/// - Inserted after cognitiveHeavy or after accumulated load >= breakThreshold
/// - Never two hobbies consecutively unless unavoidable
class RoutineGenerator {
    /// Minutes of accumulated load before inserting a hobby
    private let breakThreshold = 90
    private let userPreferences: UserInstructionsParser.Adjustments
    private let hobbySelector: HobbySelector

    init(instructions: String = "") {
        self.userPreferences = UserInstructionsParser.parse(instructions)
        let configuration = HobbySelectorConfiguration(
            adjustments: userPreferences
        )
        self.hobbySelector = HobbySelector(config: configuration)
    }

    /**
        Orders tasks according to its type to avoid consecutive heavy tasks and front-load physical ones.

        - Parameter tasks: the unordered tasks array

        - Returns: the same array, now ordered
     */
    private func orderTasks(_ tasks: [MatchedTask]) -> [MatchedTask] {
        let physical = tasks.filter {
            $0.classification?.activityType == .physical
        }
        let heavy = tasks.filter {
            $0.classification?.activityType == .cognitiveHeavy
        }
        let medium = tasks.filter {
            $0.classification?.activityType == .cognitiveMedium
        }
        let light = tasks.filter {
            $0.classification?.activityType == .cognitiveLight
        }
        let domestic = tasks.filter {
            $0.classification?.activityType == .domestic
        }
        let unclassified = tasks.filter {
            $0.classification == nil || $0.classification?.activityType == nil
        }

        let buffers = (light + domestic).shuffled()

        // Interleave heavy tasks with buffers
        var ordered: [MatchedTask] = physical  // First, insert all physical tasks
        var bufferIndex = 0
        var lastWasHeavy = false

        // Then, get all heavy and medium, shuffled
        let heavyAndMedium = (heavy + medium).shuffled()

        // Now, iterate through them to insert buffer tasks between those
        for task in heavyAndMedium {
            let isHeavy = TaskLoadEvaluator.isHeavy(task: task)

            if lastWasHeavy && isHeavy && bufferIndex < buffers.count {
                // Two consecutive heavy tasks and there are remaining buffers
                // add a buffer
                ordered.append(buffers[bufferIndex])
                bufferIndex += 1
            }

            ordered.append(task)
            lastWasHeavy = isHeavy
        }

        // Append remaining buffers
        while bufferIndex < buffers.count {
            ordered.append(buffers[bufferIndex])
            bufferIndex += 1
        }
        
        // Append unclassified tasks
        for task in unclassified {
            ordered.append(task)
            
        }

        return ordered
    }

    /**
        Interleaves hobbies into the ordered task list based on accumulated load.

        - Parameter tasks: the ordered tasks array
        - Parameter hobbies: the selected hobbies for this day (ordered)

        - Returns: the ordered array of activities
     */
    private func orderActivities(tasks: [MatchedTask], hobbies: [SelectedHobby])
        -> [Activity]
    {
        let orderedTasks = orderTasks(tasks)

        var result = [Activity]()
        var remainingHobbies = hobbies
        var accumulatedLoad = 0
        var activityIndex = 0
        var lastWasHobby = false

        for task in orderedTasks {
            result.append(Activity(task: task.task, order: activityIndex))
            activityIndex += 1

            let duration = task.classification?.estimatedDuration ?? 0
            accumulatedLoad += duration

            let isHeavy = TaskLoadEvaluator.isHeavy(task: task)
            let shouldBreak = isHeavy || accumulatedLoad >= breakThreshold

            if shouldBreak && !lastWasHobby && !remainingHobbies.isEmpty {
                let hobby = remainingHobbies.removeFirst()
                result
                    .append(
                        Activity(
                            hobby: hobby.hobby,
                            durationInMin: hobby.durationInMinutes,
                            order: activityIndex
                        )
                    )
                activityIndex += 1
                accumulatedLoad = 0
                lastWasHobby = true
            } else {
                lastWasHobby = false
            }
        }

        // Append remaining hobbies at the end
        for hobby in remainingHobbies {
            result
                .append(
                    Activity(
                        hobby: hobby.hobby,
                        durationInMin: hobby.durationInMinutes,
                        order: activityIndex
                    )
                )
        }

        return result
    }

    func generate(tasks: [MatchedTask], hobbies: [Hobby]) -> Routine {
        let selectedHobbies = hobbySelector.select(
            for: .now,
            tasks: tasks,
            hobbies: hobbies
        )

        let activities = orderActivities(tasks: tasks, hobbies: selectedHobbies)

        return Routine(activities: activities)
    }
}
