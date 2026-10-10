import Foundation
import SwiftData

/// A draft deliberately holds no Activity relationships until validation succeeds.
struct PlannedActivity {
    var task: MyTask? = nil
    var hobby: Hobby? = nil
    var durationInMin: Int? = nil

    static func validate(_ draft: [Self], tasks: [MyTask], hobbies: [Hobby]) throws {
        let taskIDs = draft.compactMap { $0.task?.persistentModelID }
        let hobbyIDs = draft.compactMap { $0.hobby?.persistentModelID }
        guard taskIDs.count == tasks.count, Set(taskIDs).count == taskIDs.count,
              Set(taskIDs) == Set(tasks.map(\.persistentModelID)),
              Set(hobbyIDs).count == hobbyIDs.count,
              Set(hobbyIDs).isSubset(of: Set(hobbies.map(\.persistentModelID))) else {
            throw OnDeviceAI.Failure.invalidResponse
        }
        for item in draft {
            guard (item.task != nil) != (item.hobby != nil) else {
                throw OnDeviceAI.Failure.invalidResponse
            }
            if let hobby = item.hobby {
                guard let duration = item.durationInMin, (1...720).contains(duration),
                      duration >= (hobby.minimumDurationInMinutes ?? 15) else {
                    throw OnDeviceAI.Failure.invalidResponse
                }
            }
        }
    }
}
