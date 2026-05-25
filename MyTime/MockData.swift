//
//  MockData.swift
//  MyTime
//
//  Created by Welton Felix on 23/05/26.
//

import Foundation
import SwiftData

func mockContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Routine.self,
        configurations: config
    )

    let tasks = [
        MyTask(taskDescription: "Estudar algoritmos"),
        MyTask(taskDescription: "Limpar meu quarto"),
        MyTask(taskDescription: "Fazer exercícios"),
    ]

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

    let tasksActivities = tasks.map { task in
        Activity(task: task, isCompleted: Bool.random())
    }
    let hobbiesActivities = hobbies.map { hobby in
        Activity(hobby: hobby, durationInMin: 30)
    }

    let activities: [Activity] = [
        tasksActivities[0], tasksActivities[1], hobbiesActivities[0],
        tasksActivities[2], hobbiesActivities[1],
    ]
    
    for (index, activity) in activities.enumerated() {
        activity.order = index
    }
    let routine = Routine(activities: activities)
    container.mainContext.insert(routine)

    return container
}
