//
//  TimeInterval+Formatted.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import Foundation

extension TimeInterval {
    var formattedAsTimer: String {
        let total = Int(self)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
