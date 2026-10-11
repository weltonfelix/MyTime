//
//  UserInstructionsParser.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation

struct UserInstructionsParser {
    
    // MARK: - Adjustment results
    
    struct Adjustments: Equatable {
        var excludeHobbies = false
        var preferShortSessions = false
        var maxFactorDelta: Double = 0      // added to maxFactor
        var availableMinutesDelta: Int = 0  // added to availableDayMinutes
        var preferLowEnergy: Bool = false   // prioritize low energy hobbies
    }
    
    // MARK: - Keyword groups
    
    private static let fewerHobbies = [
        "menos hobbies", "poucos hobbies", "menos lazer",
        "menos pausas", "menos descanso", "sem hobbies",
        "foco no trabalho", "foco nas tarefas", "dia produtivo",
        "quero produzir", "sem distrações", "sem distracao",
        "maximizar produtividade", "dia de foco",
        "fewer hobbies", "less leisure", "fewer breaks", "no hobbies",
        "focus on work", "focus on tasks"
    ]

    private static let moreHobbies = [
        "mais hobbies", "mais lazer", "mais pausas",
        "mais descanso", "mais breaks", "quero descansar",
        "preciso descansar", "dia mais leve", "menos trabalho",
        "mais tempo livre", "equilibrio", "balance",
        "intercalar bastante", "muitas pausas", "bastante lazer",
        "more hobbies", "more leisure", "more breaks", "more rest"
    ]

    private static let lessTime = [
        "pouco tempo", "dia corrido", "dia ocupado",
        "agenda cheia", "sem tempo", "correria",
        "dia cheio", "muitas reunioes", "muitas reuniões",
        "compromissos", "tempo curto", "apertado",
        "sem folga", "dia intenso", "dia pesado",
        "little time", "little free time", "busy day", "full schedule", "no time"
    ]

    private static let moreTime = [
        "dia livre", "bastante tempo", "dia tranquilo",
        "tempo livre", "folga", "dia relaxado",
        "sem compromissos", "dia vazio", "agenda vazia",
        "dia calmo", "sem pressa", "tempo sobrando",
        "dia de descanso", "fim de semana tranquilo",
        "free day", "plenty of time", "plenty of free time", "free time", "empty schedule"
    ]

    private static let lowEnergy = [
        "cansado", "sem energia", "estressado",
        "exausto", "cansada", "estressada", "exausta",
        "esgotado", "esgotada", "sobrecarregado", "sobrecarregada",
        "mal dormido", "mal dormida", "sem disposição", "sem disposicao",
        "desanimado", "desanimada", "com sono", "sonolento",
        "burnout", "no limite", "tired", "exhausted", "stressed",
        "low energy", "no energy", "sleepy", "overwhelmed"
    ]
    
    private static let shortSessions = [
        "pausas curtas", "sessoes curtas", "hobbies curtos", "intervalos curtos",
        "short breaks", "short sessions", "short hobby sessions", "short hobbies",
        "keep hobbies short", "keep hobby sessions short"
    ]

    // shortcut: only known phrases and nearby simple negations; use the AI path for complex instructions.
    private static func containsAffirmed(_ phrases: [String], in text: String) -> Bool {
        phrases.contains { phrase in
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: phrase.normalized) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).contains { match in
                guard let range = Range(match.range, in: text) else { return false }
                let prefix = String(text[..<range.lowerBound])
                let negation = #"\b(?:nao|not|no|never|don't|dont|sem|without)\s+(?:(?:estou|estamos|quero|queremos|preciso|tenho|ficar|estar|ser|me|sinto|mais|muito|tao|really|very|want|need|have|be|feel|feeling|any)\s+){0,3}$"#
                return prefix.range(of: negation, options: .regularExpression) == nil
            }
        }
    }

    // MARK: - Parse
    
    /**
        Parses free-text user instructions into concrete adjustments
        for the routine generation algorithm.
     
        - Parameter instructions: raw text from user preferences
        - Returns: adjustments to apply to the routine generator
     */
    static func parse(_ instructions: String) -> Adjustments {
        let text = instructions.normalized.replacingOccurrences(of: "’", with: "'")
        
        var adjustments = Adjustments()
        
        if containsAffirmed(fewerHobbies, in: text) {
            adjustments.maxFactorDelta -= 0.15
        }
        
        if containsAffirmed(moreHobbies, in: text) {
            adjustments.maxFactorDelta += 0.15
        }
        
        if containsAffirmed(lessTime, in: text) {
            adjustments.availableMinutesDelta -= 120
        }
        
        // Scarcity phrases include "free time" but must not also increase the budget.
        let moreTimeText = text.replacingOccurrences(of: "pouco tempo livre", with: "pouco tempo")
            .replacingOccurrences(of: "little free time", with: "little time")
        if containsAffirmed(moreTime, in: moreTimeText) {
            adjustments.availableMinutesDelta += 120
        }
        
        if containsAffirmed(lowEnergy, in: text) {
            adjustments.preferLowEnergy = true
            adjustments.maxFactorDelta += 0.1 // mais pausas quando cansado
        }
        
        adjustments.preferShortSessions = containsAffirmed(shortSessions, in: text)
        adjustments.excludeHobbies = containsAffirmed(["sem hobbies", "no hobbies"], in: text)
        return adjustments
    }
}
