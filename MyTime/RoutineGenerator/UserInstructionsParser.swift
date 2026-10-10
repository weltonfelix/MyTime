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
        "maximizar produtividade", "dia de foco"
    ]

    private static let moreHobbies = [
        "mais hobbies", "mais lazer", "mais pausas",
        "mais descanso", "mais breaks", "quero descansar",
        "preciso descansar", "dia mais leve", "menos trabalho",
        "mais tempo livre", "equilibrio", "balance",
        "intercalar bastante", "muitas pausas", "bastante lazer"
    ]

    private static let lessTime = [
        "pouco tempo", "dia corrido", "dia ocupado",
        "agenda cheia", "sem tempo", "correria",
        "dia cheio", "muitas reunioes", "muitas reuniões",
        "compromissos", "tempo curto", "apertado",
        "sem folga", "dia intenso", "dia pesado"
    ]

    private static let moreTime = [
        "dia livre", "bastante tempo", "dia tranquilo",
        "tempo livre", "folga", "dia relaxado",
        "sem compromissos", "dia vazio", "agenda vazia",
        "dia calmo", "sem pressa", "tempo sobrando",
        "dia de descanso", "fim de semana tranquilo"
    ]

    private static let lowEnergy = [
        "cansado", "sem energia", "estressado",
        "exausto", "cansada", "estressada", "exausta",
        "esgotado", "esgotada", "sobrecarregado", "sobrecarregada",
        "mal dormido", "mal dormida", "sem disposição", "sem disposicao",
        "desanimado", "desanimada", "com sono", "sonolento",
        "burnout", "no limite"
    ]
    
    // MARK: - Parse
    
    /**
        Parses free-text user instructions into concrete adjustments
        for the routine generation algorithm.
     
        - Parameter instructions: raw text from user preferences
        - Returns: adjustments to apply to the routine generator
     */
    static func parse(_ instructions: String) -> Adjustments {
        let text = instructions.normalized
        
        var adjustments = Adjustments()
        
        if fewerHobbies.contains(where: { text.contains($0.normalized) }) {
            adjustments.maxFactorDelta -= 0.15
        }
        
        if moreHobbies.contains(where: { text.contains($0.normalized) }) {
            adjustments.maxFactorDelta += 0.15
        }
        
        if lessTime.contains(where: { text.contains($0.normalized) }) {
            adjustments.availableMinutesDelta -= 120
        }
        
        if moreTime.contains(where: { text.contains($0.normalized) }) {
            adjustments.availableMinutesDelta += 120
        }
        
        if lowEnergy.contains(where: { text.contains($0.normalized) }) {
            adjustments.preferLowEnergy = true
            adjustments.maxFactorDelta += 0.1 // mais pausas quando cansado
        }
        
        adjustments.excludeHobbies = text.contains("sem hobbies") || text.contains("no hobbies")
        return adjustments
    }
}
