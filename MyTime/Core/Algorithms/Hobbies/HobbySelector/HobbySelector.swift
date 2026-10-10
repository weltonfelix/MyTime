//
//  HobbySelector.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation

struct SelectedHobby {
    let hobby: Hobby
    let durationInMinutes: Int
}

class HobbySelector {
    private let config: HobbySelectorConfiguration
    private let loadEvaluator: TaskLoadEvaluator

    init(
        config: HobbySelectorConfiguration = .init()
    ) {
        self.config = config
        self.loadEvaluator = TaskLoadEvaluator()
    }
    /**
        Returns a priority score for a hobby based on its energy level and the day's load.

        High-energy hobbies are penalized on heavy days; low-energy ones are prioritized.

        - Parameter level: the hobby energy level
        - Parameter cognitiveScore: the cognitive score of the day [0-1]
        - Parameter physicalScore: the physical score of the day [0-1]

        - Returns: a score between 0 and 1
     */
    private func hobbyScore(
        for level: HobbyEnergyLevel?,
        cognitiveScore: Double,
        physicalScore: Double
    ) -> Int {
        guard let level else { return 0 }

        let isHeavyDay =
            physicalScore >= config.heavyDayPhysicalThreshold
            || cognitiveScore >= config.heavyDayCognitiveThreshold
            || config.preferLowEnergy

        switch level {
        case .high:
            return isHeavyDay
                ? config.penalizedEnergyScore : config.normalEnergyScore
        case .medium: return config.normalEnergyScore
        case .low:
            return isHeavyDay
                ? config.prioritizedEnergyScore : config.normalEnergyScore
        }
    }

    /**
        Order hobbies based on the cognitive and physical score of the day

        Longer hobbies are prioritized

        - Parameter hobbies: the hobbies to order
        - Parameter cognitiveScore: the cognitive score of the day [0-1]
        - Parameter physicalScore: the physical score of the day [0-1]

        - Returns: the hobbies array sorted
     */
    private func prioritize(
        _ hobbies: [Hobby],
        cognitiveScore: Double,
        physicalScore: Double
    ) -> [Hobby] {
        hobbies.sorted {
            a,
            b in
            let aHobbyScore = hobbyScore(
                for: a.energyLevel,
                cognitiveScore: cognitiveScore,
                physicalScore: physicalScore
            )
            let bHobbyScore = hobbyScore(
                for: b.energyLevel,
                cognitiveScore: cognitiveScore,
                physicalScore: physicalScore
            )

            if aHobbyScore != bHobbyScore {
                return aHobbyScore > bHobbyScore
            }

            // Tie breaker: longer hobbies first
            return (a.minimumDurationInMinutes ?? 0)
                > (b.minimumDurationInMinutes ?? 0)
        }
    }

    /**
        Greedily selects hobbies that fit within the available time budget,
        using each hobby's minimum duration as its time cost.

        - Parameter maxMinutes: the maximum total minutes available for hobbies
        - Parameter hobbies: the hobbies to select from, in priority order

        - Returns: the largest subset of hobbies whose minimum durations fit within maxMinutes
     */

    private func fillUpTo(_ maxMinutes: Int, from hobbies: [Hobby]) -> [Hobby] {
        var selected: [Hobby] = []
        var accumulated = 0

        for hobby in hobbies {
            let duration = hobby.minimumDurationInMinutes ?? 15
            if accumulated + duration <= maxMinutes {
                selected.append(hobby)
                accumulated += duration
            }
        }

        return selected
    }

    /**
        Distributes available time among selected hobbies, assigning each a concrete duration.

        Reserve every minimum duration first, then divide the remaining time using
        uniform and proportional weights. Round extra allocations down; the last hobby
        absorbs the remainder without exceeding the budget.

        - Parameter maxMinutes: total minutes to distribute among hobbies
        - Parameter hobbies: the hobbies to assign durations to, in order

        - Returns: hobbies paired with their assigned duration in minutes
     */
    private func distributeTime(_ maxMinutes: Int, among hobbies: [Hobby])
        -> [SelectedHobby]
    {
        guard !hobbies.isEmpty else { return [] }

        let minimums = hobbies.map { $0.minimumDurationInMinutes ?? config.defaultMinimumDuration }
        let totalMinimum = minimums.reduce(0, +)
        guard totalMinimum <= maxMinutes else { return [] }
        if config.preferShortSessions {
            return zip(hobbies, minimums).map { SelectedHobby(hobby: $0, durationInMinutes: $1) }
        }
        let extra = maxMinutes - totalMinimum
        var remainingExtra = extra
        var result: [SelectedHobby] = []
        for (index, hobby) in hobbies.enumerated() {
            let share = config.uniformWeight / Double(hobbies.count)
                + config.proportionalWeight * Double(minimums[index]) / Double(totalMinimum)
            let allocation = index == hobbies.count - 1 ? remainingExtra
                : min(remainingExtra, Int(Double(extra) * share) / config.roundingBase * config.roundingBase)
            result.append(SelectedHobby(hobby: hobby, durationInMinutes: minimums[index] + allocation))
            remainingExtra -= allocation
        }

        return result
    }

    /**
        Selects and schedules hobbies for a given day based on task load and hobby preferences.

        The process:
        1. Calculates available time for hobbies based on cognitive and physical load of tasks
        2. Splits hobbies into preferred (day-specific) and others
        3. Fills available time with preferred hobbies first, then others
        4. Caps at `maxHobbies`, adding a fourth only if significant time remains
        5. Distributes time among selected hobbies

        - Parameter date: the target day (defaults to today)
        - Parameter tasks: classified tasks scheduled for the day
        - Parameter hobbies: all available hobbies to choose from

        - Returns: selected hobbies with their assigned durations
     */
    func select(
        for date: Date = .now,
        tasks: [MatchedTask],
        hobbies: [Hobby]
    ) -> [SelectedHobby] {
        guard !hobbies.isEmpty, !config.excludeHobbies else { return [] }
        let hobbies = hobbies.filter { (1...720).contains($0.minimumDurationInMinutes ?? config.defaultMinimumDuration) }
        guard !hobbies.isEmpty else { return [] }

        // MARK: - Time budget

        let taskLoad = tasks.reduce(0) {
            $0 + ($1.classification?.estimatedDuration ?? 30)
        }
        let remainingMinutes = max(0, config.availableDayMinutes - taskLoad)
        guard remainingMinutes > 0 else { return [] }

        let cognitiveScore = loadEvaluator.cognitiveScore(tasks: tasks)
        let physicalScore = loadEvaluator.physicalScore(tasks: tasks)

        let cognitiveFactor: Double
        switch cognitiveScore {
        case config.heavyCognitiveThreshold...:
            cognitiveFactor = config.heavyCognitiveFactor
        case config.mediumCognitiveThreshold..<config.heavyCognitiveThreshold:
            cognitiveFactor = config.mediumCognitiveFactor
        default: cognitiveFactor = config.lightCognitiveFactor
        }

        let physicalFactor: Double
        switch physicalScore {
        case config.highPhysicalThreshold...:
            physicalFactor = config.highPhysicalFactor
        case config.mediumPhysicalThreshold..<config.highPhysicalThreshold:
            physicalFactor = config.mediumPhysicalFactor
        default: physicalFactor = 0.0
        }

        let maxHobbyMinutes = Int(
            Double(remainingMinutes)
                * min(cognitiveFactor + physicalFactor, config.effectiveMaxFactor)
        )

        guard maxHobbyMinutes > 0 else { return [] }

        // MARK: - Hobby splitting

        let today = HobbyPreferredDay.from(date)

        let preferred = hobbies.filter { hobby in
            guard let days = hobby.preferredDays else { return false }
            return days.contains(today) && config.shouldIncludePreferred
        }

        let preferredSet = Set(preferred.map { ObjectIdentifier($0) })

        let others = hobbies.filter { hobby in
            let isPreferredDay = hobby.preferredDays?.contains(today) ?? false
            let wasExcludedByChance =
                isPreferredDay
                && !preferredSet.contains(ObjectIdentifier(hobby))
            let hasNoPreference = hobby.preferredDays == nil

            return hasNoPreference || wasExcludedByChance
        }

        // MARK: - Selection

        let selectedPreferred = fillUpTo(
            maxHobbyMinutes,
            from: prioritize(
                preferred,
                cognitiveScore: cognitiveScore,
                physicalScore: physicalScore
            )
        )
        let remainingAfterPreferred =
            maxHobbyMinutes
            - selectedPreferred.reduce(0) {
                $0
                    + ($1.minimumDurationInMinutes
                        ?? config.defaultMinimumDuration)
            }

        let selectedOthers = fillUpTo(
            remainingAfterPreferred,
            from: prioritize(
                others,
                cognitiveScore: cognitiveScore,
                physicalScore: physicalScore
            )
        )

        let candidates = selectedPreferred + selectedOthers
        var final = Array(candidates.prefix(config.maxHobbies))

        // MARK: - Optional fourth hobby

        let usedByMinimums = final.reduce(0) {
            $0 + ($1.minimumDurationInMinutes ?? config.defaultMinimumDuration)
        }
        let utilizationRate = Double(usedByMinimums) / Double(maxHobbyMinutes)

        if utilizationRate < config.utilizationThreshold,
            let fourth = candidates.dropFirst(config.maxHobbies).first
        {
            let leftover = maxHobbyMinutes - usedByMinimums
            if leftover
                >= (fourth.minimumDurationInMinutes
                    ?? config.defaultMinimumDuration)
            {
                final.append(fourth)
            }
        }

        return distributeTime(maxHobbyMinutes, among: final)
    }
}
