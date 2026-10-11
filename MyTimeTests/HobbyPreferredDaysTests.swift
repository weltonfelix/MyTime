import Testing
@testable import MyTime

@MainActor
struct HobbyPreferredDaysTests {
    private func days(_ description: String) -> [HobbyPreferredDay]? {
        Hobby(title: "Hobby", hobbyDescription: description).preferredDays
    }

    @Test func specificDaysTakePriorityOverWeeklyFrequency() {
        #expect(days("Correr aos domingos, uma vez por semana") == [.sunday])
        #expect(days("Run on Sundays, once a week") == [.sunday])
        #expect(days("Terças e quintas, duas vezes por semana") == [.tuesday, .thursday])
        #expect(days("Domingo no fim de semana") == [.sunday])
        #expect(days("No domingo") == [.sunday])
    }

    @Test func explicitGroups() {
        #expect(days("Nos dias úteis") == [.monday, .tuesday, .wednesday, .thursday, .friday])
        #expect(days("On weekdays") == [.monday, .tuesday, .wednesday, .thursday, .friday])
        #expect(days("Nos fins de semana") == [.saturday, .sunday])
        #expect(days("On weekends") == [.saturday, .sunday])
    }

    @Test func ambiguousAndUnsupportedDescriptionsStayUnrestricted() {
        for description in ["", "Uma vez por semana", "Semanalmente", "Weekday routine sometime",
                            "Exceto domingo", "Não aos domingos",
                            "Not on Sunday", "Nunca aos domingos", "No Sundays", "Avoid Sunday", "Sem preferência", "Segunda a sexta", "Monday to Friday", "Monday-Friday", "Segunda-feira–sexta-feira"] {
            #expect(days(description) == nil)
        }
    }
}
