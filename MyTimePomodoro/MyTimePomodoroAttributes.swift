//
//  MyTimePomodoroAttributes.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import Foundation
import ActivityKit

nonisolated struct MyTimePomodoroAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var currentSession: Int
        var pomodoroStatus: String
        var endDate: Date?
        var stageDuration: TimeInterval
        var remainingOnPause: TimeInterval?
    }
}
