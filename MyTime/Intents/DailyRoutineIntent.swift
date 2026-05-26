//
//  DailyRoutineIntent.swift
//  MyTime
//
//  Created by Welton Felix on 26/05/26.
//

import AppIntents
import Foundation
import SwiftData

struct GetDailyRoutineIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Daily Routine"
    static var description = IntentDescription("Siri reads your daily routine")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog
    {
        guard let context = try? ModelContext(ModelContainer(for: Routine.self))
        else {
            return .result(
                value: "",
                dialog: "I couldn't access MyTime data at the moment."
            )
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<Routine> { routine in
            routine.date >= startOfDay && routine.date < endOfDay
        }

        let descriptor = FetchDescriptor<Routine>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        do {
            let routines = try context.fetch(descriptor)

            guard !routines.isEmpty, let routine = routines.first else {
                return .result(
                    value: String(localized: "Your routine is empty"),
                    dialog: "You don't have any tasks or hobbies for today."
                )
            }

            if routine.activities.isEmpty {
                return .result(
                    value: String(localized: "Your routine is empty"),
                    dialog: "You don't have any tasks or hobbies for today."
                )

            }

            var siriText = String(
                localized: "Here's your activities for today: "
            )

            for (index, activity) in routine.activities.enumerated() {
                let separator: String
                if index == routine.activities.count - 1 {
                    separator = "."
                } else if index == routine.activities.count - 2 {
                    separator = " and "
                } else {
                    separator = ", "
                }

                if let hobby = activity.hobby {
                    siriText.append("\(hobby.title)\(separator)")
                }

                if let task = activity.task {
                    siriText.append("\(task.taskDescription)\(separator)")
                }

            }

            return .result(value: siriText, dialog: "\(siriText)")

        } catch {
            return .result(
                value: "",
                dialog: "There was an error retrieving your routine."
            )
        }
    }
}
