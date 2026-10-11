import Foundation
import Testing
@testable import MyTime

struct TimeIntervalFormattingTests {
    @Test func visualTimersSwitchToHoursAtOneHour() {
        for (seconds, expected) in [(-1.0, "0:00"), (0.0, "0:00"), (59.9, "0:59"), (3599.0, "59:59"), (3600.0, "1:00:00"), (5014.0, "1:23:34"), (9000.0, "2:30:00")] {
            #expect(seconds.formattedAsTimer == expected)
        }
    }

    @Test func accessibleDurationsUseHoursMinutesAndSeconds() {
        for (seconds, expected) in [(0.0, [0]), (-1.0, [0]), (59.1, [1]), (1499.0, [24, 59]), (6600.0, [1, 50]), (6900.0, [1, 55]), (9000.0, [2, 30])] {
            let spokenNumbers = seconds.formattedForAccessibility
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap(Int.init)
            #expect(spokenNumbers == expected)
        }
    }
}
