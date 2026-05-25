//
//  DesignSystem.swift
//  MyTime
//
//  Created by Welton Felix on 5/16/26.
//

import SwiftUI

extension LinearGradient {
    static var hobbyGradient: LinearGradient {
        LinearGradient(
            stops: [
                Gradient.Stop(color: .pink, location: 0.15),
                Gradient.Stop(color: .purple, location: 0.44),
                Gradient.Stop(color: .indigo, location: 0.69),
                Gradient.Stop(color: .blue, location: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
