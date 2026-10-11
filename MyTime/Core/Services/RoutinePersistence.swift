import Foundation
import SwiftData

@MainActor
enum RoutinePersistence {
    static func removeExpired(in context: ModelContext, now: Date = .now) throws -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: now)
        let expired = try context.fetch(FetchDescriptor<Routine>()).filter { $0.date < startOfDay }
        guard !expired.isEmpty else { return false }
        try context.save()
        do {
            for routine in expired {
                for activity in routine.activities where activity.isCompleted {
                    if let task = activity.task { context.delete(task) }
                }
                context.delete(routine)
            }
            try context.save()
            return true
        } catch {
            context.rollback()
            throw error
        }
    }

    static func replace(with draft: [PlannedActivity], in context: ModelContext,
                        preserveCompletion: Bool = false,
                        save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        let tasks = try context.fetch(FetchDescriptor<MyTask>())
        let hobbies = try context.fetch(FetchDescriptor<Hobby>())
        try PlannedActivity.validate(draft, tasks: tasks, hobbies: hobbies)
        // Establish a rollback boundary that preserves the user's edits.
        try context.save()
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        let oldRoutines = try context.fetch(FetchDescriptor<Routine>())
        let completedTasks = Set(oldRoutines.flatMap { $0.activities }.filter(\.isCompleted).compactMap { $0.task?.persistentModelID })
        let completedHobbies = Set(oldRoutines.flatMap { $0.activities }.filter(\.isCompleted).compactMap { $0.hobby?.persistentModelID })
        let previousActivities = oldRoutines.map { ($0, $0.activities) }
        let previousHobbyActivities = hobbies.map { ($0, $0.activities) }
        let previousLinks = oldRoutines.flatMap { routine in
            routine.activities.map { ($0, $0.task, $0.hobby, routine) }
        }
        do {
            // Detach inverses before assigning each task's one-to-one replacement activity.
            for routine in oldRoutines {
                for activity in routine.activities {
                    activity.task = nil
                    activity.hobby = nil
                }
                context.delete(routine)
            }
            let activities = draft.enumerated().map { index, item in
                if let task = item.task {
                    return Activity(task: task, isCompleted: preserveCompletion && completedTasks.contains(task.persistentModelID), order: index)
                }
                let activity = Activity(hobby: item.hobby, durationInMin: item.durationInMin, order: index)
                activity.isCompleted = preserveCompletion && item.hobby.map { completedHobbies.contains($0.persistentModelID) } == true
                return activity
            }
            context.insert(Routine(activities: activities))
            try save(context)
        } catch {
            context.rollback()
            // SwiftData rollback may leave cached inverses pointing at discarded inserts.
            for (routine, activities) in previousActivities { routine.activities = activities }
            for (hobby, activities) in previousHobbyActivities { hobby.activities = activities }
            for (activity, task, hobby, routine) in previousLinks {
                activity.task = task
                task?.activity = activity
                activity.hobby = hobby
                activity.routine = routine
            }
            throw error
        }
    }
}
