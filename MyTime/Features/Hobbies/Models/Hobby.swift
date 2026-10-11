//
//  Hobby.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import Foundation
import SwiftData

enum HobbyEnergyLevel: String, Codable {
    case high
    case medium
    case low
}

enum HobbyPreferredDay: String, Codable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    
    static func from(_ date: Date) -> Self {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
}

@Model
class Hobby {
    var title: String
    var hobbyDescription: String
    var createdAt = Date.now
    @Relationship(deleteRule: .cascade, inverse: \Activity.hobby)
    var activities = [Activity]()

    var energyLevel: HobbyEnergyLevel?
    var minimumDurationInMinutes: Int?

    init(title: String, hobbyDescription: String) {
        self.title = title
        self.hobbyDescription = hobbyDescription
    }

    var preferredDays: [HobbyPreferredDay]? {
        guard !hobbyDescription.isEmpty else { return nil }

        let text = hobbyDescription.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        // shortcut: negations and day ranges are not interpreted; leave these descriptions unrestricted.
        let unsupported = #"\b(?:nao|nunca|jamais|not|never|except|exceto|menos|sem|without|cannot|can't|don't|avoid)\b|\bno\s+(?:mondays?|tuesdays?|wednesdays?|thursdays?|fridays?|saturdays?|sundays?|weekdays|weekends)\b|\b(?:segunda|terca|quarta|quinta|sexta|sabado|domingo|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:-feira)?(?:\s+(?:a|ate|to|through)\s+|\s*[-–—]\s*)"#
        guard text.range(of: unsupported, options: .regularExpression) == nil else { return nil }

        // Specific days
        var days: [HobbyPreferredDay] = []
        let dayMappings: [(keywords: [String], day: HobbyPreferredDay)] = [
            (["segunda", "monday"], .monday),
            (["terca", "tuesday"], .tuesday),
            (["quarta", "wednesday"], .wednesday),
            (["quinta", "thursday"], .thursday),
            (["sexta", "friday"], .friday),
            (["sabado", "saturday"], .saturday),
            (["domingo", "sunday"], .sunday),
        ]

        for mapping in dayMappings {
            if mapping.keywords.contains(where: {
                text.range(of: "\\b" + $0 + "s?\\b", options: .regularExpression) != nil
            }) {
                days.append(mapping.day)
            }
        }

        if !days.isEmpty { return days }

        // Weekends
        if text.contains("fim de semana")
            || text.contains("final de semana")
            || text.contains("fins de semana")
            || text.contains("finais de semana")
            || text.contains("weekend")
        {
            return [.saturday, .sunday]
        }

        // Weekdays
        if text.contains("dia util")
            || text.contains("dias uteis")
            || text.contains("weekdays")
        {
            return [.monday, .tuesday, .wednesday, .thursday, .friday]
        }

        return nil
    }

}
