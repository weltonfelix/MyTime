//
//  Task.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftData
import Foundation

@Model
class MyTask {
    var taskDescription: String
    var createdAt = Date.now
    @Relationship(deleteRule: .cascade, inverse: \Activity.task)
    var activity: Activity?
    
    init(taskDescription: String) {
        self.taskDescription = taskDescription
    }
}
