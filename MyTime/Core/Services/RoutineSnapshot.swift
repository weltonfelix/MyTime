import Foundation
import SwiftData

struct RoutineSnapshot: Equatable {
    let tasks: [PersistentIdentifier: String]
    let hobbies: [PersistentIdentifier: [String]]
    let instructions: String
    let day: Date

    init(tasks: [MyTask], hobbies: [Hobby], instructions: String, date: Date = .now) {
        self.tasks = Dictionary(uniqueKeysWithValues: tasks.map { ($0.persistentModelID, $0.taskDescription) })
        self.hobbies = Dictionary(uniqueKeysWithValues: hobbies.map {
            ($0.persistentModelID, [$0.title, $0.hobbyDescription, $0.energyLevel?.rawValue ?? "",
                $0.minimumDurationInMinutes.map(String.init) ?? ""])
        })
        self.instructions = instructions
        day = Calendar.current.startOfDay(for: date)
    }
}
