import Testing
import Foundation
@testable import ChinGoEngine

@Suite("Age gate")
struct AgeGateTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Someone comfortably over the line gets in")
    func adultPasses() {
        let tier = AgeGate.tier(bornOn: date(1990, 6, 1), asOf: date(2026, 9, 4), calendar: calendar)
        #expect(tier == .adult)
    }

    @Test("Someone comfortably under it does not")
    func childBlocked() {
        let tier = AgeGate.tier(bornOn: date(2018, 6, 1), asOf: date(2026, 9, 4), calendar: calendar)
        #expect(tier == .tooYoung)
    }

    @Test("The day before the birthday is still too young")
    func dayBeforeIsTooYoung() {
        // Born 5 September 2010, checked 4 September 2026: sixteen tomorrow, not today.
        // Anything that divides seconds by 31_536_000 gets this wrong.
        let tier = AgeGate.tier(bornOn: date(2010, 9, 5), asOf: date(2026, 9, 4), calendar: calendar)
        #expect(tier == .tooYoung)
    }

    @Test("The birthday itself passes")
    func birthdayPasses() {
        let tier = AgeGate.tier(bornOn: date(2010, 9, 4), asOf: date(2026, 9, 4), calendar: calendar)
        #expect(tier == .adult)
    }

    @Test("Born on a leap day, checked in a non-leap year")
    func leapDayBirthday() {
        // 29 February 2008 turns 16 during 2024, a year with no 29 February. The calendar
        // resolves this; subtracting timestamps does not.
        #expect(AgeGate.tier(bornOn: date(2008, 2, 29), asOf: date(2024, 2, 28), calendar: calendar) == .tooYoung)
        #expect(AgeGate.tier(bornOn: date(2008, 2, 29), asOf: date(2024, 3, 1), calendar: calendar) == .adult)
    }

    @Test("The floor is sixteen, and it is deliberate")
    func floorIsSixteen() {
        #expect(AgeGate.minimumAge == 16)
    }
}
