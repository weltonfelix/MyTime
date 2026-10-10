//
//  HobbySelectorConfiguration.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation

struct HobbySelectorConfiguration {
    var availableDayMinutes: Int

    var excludeHobbies = false
    var preferShortSessions = false
    var preferLowEnergy: Bool = false
    var maxFactorDelta: Double = 0

    // MARK: Cognitive factors
    let heavyCognitiveFactor = 0.6
    let mediumCognitiveFactor = 0.5
    let lightCognitiveFactor = 0.4
    let heavyCognitiveThreshold = 0.6
    let mediumCognitiveThreshold = 0.3

    // MARK: Physical factors
    let highPhysicalFactor = 0.15
    let mediumPhysicalFactor = 0.1
    let highPhysicalThreshold = 0.5
    let mediumPhysicalThreshold = 0.25

    let maxFactor = 0.7

    // MARK: Hobby selection
    let preferredInclusionProbability = 0.7
    let maxHobbies = 3
    let utilizationThreshold = 0.75
    let defaultMinimumDuration = 15

    // MARK: Time distribution
    let uniformWeight = 0.4
    let proportionalWeight = 0.6
    let roundingBase = 5

    // MARK: Energy scoring
    let penalizedEnergyScore = 1
    let normalEnergyScore = 2
    let prioritizedEnergyScore = 3
    let heavyDayPhysicalThreshold = 0.4
    let heavyDayCognitiveThreshold = 0.6

    /// Randomly determines whether a preferred hobby should be included today,
    /// introducing variety so the routine doesn't always feel identical.
    var shouldIncludePreferred: Bool {
        Double.random(in: 0...1) <= preferredInclusionProbability
    }

    var effectiveMaxFactor: Double {
        min(maxFactor + maxFactorDelta, 1.0)
    }

    init(
        availableDayMinutes: Int = 12 * 60,
        adjustments: UserInstructionsParser.Adjustments? = nil
    ) {
        self.availableDayMinutes =
            availableDayMinutes + (adjustments?.availableMinutesDelta ?? 0)
        self.excludeHobbies = adjustments?.excludeHobbies ?? false
        self.preferShortSessions = adjustments?.preferShortSessions ?? false
        self.preferLowEnergy = adjustments?.preferLowEnergy ?? false
        self.maxFactorDelta = adjustments?.maxFactorDelta ?? 0
    }
}
