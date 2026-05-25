//
//  Routine.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//
import Foundation
import SwiftData

@Model
class Routine {
    var date = Calendar.current.startOfDay(for: .now)
    @Relationship(deleteRule: .cascade, inverse: \Activity.routine)
    var activities = [Activity]()

    init(activities: [Activity] = []) {
        self.activities = activities
    }
}
