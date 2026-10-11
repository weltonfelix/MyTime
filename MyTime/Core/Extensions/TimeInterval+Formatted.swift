//
//  TimeInterval+Formatted.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import Foundation

extension TimeInterval {
    var formattedForAccessibility: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: max(0, ceil(self))) ?? String(localized: "0 seconds")
    }

    var formattedAsTimer: String {
        let total = max(0, Int(self))
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
