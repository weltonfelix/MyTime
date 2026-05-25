//
//  Activity.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftData

@Model
class Activity {
    var hobby: Hobby?
    var task: MyTask?
    var isCompleted: Bool = false
    var durationInMin: Int?
    var order: Int = 0
    var routine: Routine?

    init(
        hobby: Hobby?,
        durationInMin: Int?,
        order: Int = 0
    ) {
        self.hobby = hobby
        self.durationInMin = durationInMin
        self.order = order
    }

    init(
        task: MyTask?,
        isCompleted: Bool = false,
        order: Int = 0
    ) {
        self.task = task
        self.isCompleted = isCompleted
        self.order = order
    }

    init(
        durationInMin: Int?,
        order: Int = 0
    ) {
        self.durationInMin = durationInMin
        self.order = order
    }

}
