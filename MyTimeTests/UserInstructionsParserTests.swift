import Testing
@testable import MyTime

struct UserInstructionsParserTests {
    @Test(arguments: ["Quero pausas curtas", "Sessões curtas", "I want short breaks", "Keep hobbies short"])
    func shortSessions(_ text: String) {
        #expect(UserInstructionsParser.parse(text).preferShortSessions)
    }

    @Test(arguments: ["Não estou cansado", "Não me sinto cansada", "I'm not tired",
                      "I don't feel exhausted", "I don’t want short breaks", "Não quero pausas curtas", "I do not want short breaks"])
    func negatedPreferences(_ text: String) {
        #expect(UserInstructionsParser.parse(text) == .init())
    }

    @Test func affirmationsAfterNegation() {
        let result = UserInstructionsParser.parse("Não estou cansado, mas quero pausas curtas")
        #expect(!result.preferLowEnergy)
        #expect(result.preferShortSessions)
        #expect(UserInstructionsParser.parse("Not tired earlier; now I'm tired").preferLowEnergy)
    }

    @Test func englishAndPortugueseQuantities() {
        for text in ["Quero menos hobbies", "I want fewer hobbies"] {
            #expect(UserInstructionsParser.parse(text).maxFactorDelta == -0.15)
        }
        for text in ["Quero mais hobbies", "I want more hobbies"] {
            #expect(UserInstructionsParser.parse(text).maxFactorDelta == 0.15)
        }
        for text in ["Sem hobbies", "No hobbies"] {
            #expect(UserInstructionsParser.parse(text).excludeHobbies)
        }
        for text in ["Não quero mais hobbies", "I don't want more hobbies", "Não quero ficar sem hobbies"] {
            #expect(UserInstructionsParser.parse(text) == .init())
        }
    }

    @Test func timeScarcityDoesNotAlsoIncreaseTheBudget() {
        let english = UserInstructionsParser.parse("I have little free time; keep hobby sessions short.")
        #expect(english.availableMinutesDelta == -120)
        #expect(english.preferShortSessions)
        #expect(UserInstructionsParser.parse("Tenho pouco tempo livre").availableMinutesDelta == -120)
        #expect(UserInstructionsParser.parse("Não tenho pouco tempo livre").availableMinutesDelta == 0)
        #expect(UserInstructionsParser.parse("Busy day, but plenty of free time").availableMinutesDelta == 0)
    }

    @Test func timeAndEnergy() {
        #expect(UserInstructionsParser.parse("Busy day").availableMinutesDelta == -120)
        #expect(UserInstructionsParser.parse("Plenty of free time").availableMinutesDelta == 120)
        #expect(UserInstructionsParser.parse("I have free time").availableMinutesDelta == 120)
        #expect(UserInstructionsParser.parse("Tenho tempo livre").availableMinutesDelta == 120)
        #expect(UserInstructionsParser.parse("Sem compromissos").availableMinutesDelta == 120)
        #expect(UserInstructionsParser.parse("Sem folga").availableMinutesDelta == -120)
        #expect(UserInstructionsParser.parse("I'm tired").preferLowEnergy)
        #expect(UserInstructionsParser.parse("Estou cansada").preferLowEnergy)
        #expect(UserInstructionsParser.parse("I'm not tiredness").preferLowEnergy == false)
    }
}
