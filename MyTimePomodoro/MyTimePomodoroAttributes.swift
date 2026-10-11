//
//  MyTimePomodoroAttributes.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import Foundation
import ActivityKit
import SwiftData

nonisolated struct MyTimePomodoroAttributes: ActivityAttributes, Sendable {
    var taskID: PersistentIdentifier? = nil
    var taskTitle: String? = nil

    static func url(activityID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mytime"
        components.host = "pomodoro"
        components.path = "/" + activityID
        return components.url
    }

    public struct ContentState: Codable, Hashable, Sendable {
        var currentSession: Int
        var pomodoroStatus: String
        var endDate: Date?
        var stageDuration: TimeInterval
        var remainingOnPause: TimeInterval?
    }
}
