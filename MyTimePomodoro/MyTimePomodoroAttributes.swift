//
//  MyTimePomodoroAttributes.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import Foundation
import ActivityKit

struct MyTimePomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentSession: Int
        var pomodoroStatus: String
        var endDate: Date?
        var stageDuration: TimeInterval,
        remainingOnPause: TimeInterval?
    }
}
