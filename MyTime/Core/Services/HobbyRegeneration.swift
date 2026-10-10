import Foundation
import SwiftData

enum HobbyRegeneration {
    static func shouldOffer(initial: Set<PersistentIdentifier>, current: Set<PersistentIdentifier>,
                            routineDate: Date?, now: Date = .now) -> Bool {
        guard let routineDate, Calendar.current.isDate(routineDate, inSameDayAs: now) else { return false }
        return !current.subtracting(initial).isEmpty
    }
}
