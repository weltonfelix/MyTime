//
//  Int+Formatted.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation

extension Int {
    var formattedAsDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .brief
        return formatter.string(from: TimeInterval(self * 60)) ?? "\(self)min"
    }
}
