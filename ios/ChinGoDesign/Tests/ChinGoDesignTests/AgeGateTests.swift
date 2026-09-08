import Testing
import Foundation
@testable import ChinGoEngine

/// The gate is the one piece of this app whose failure mode is a regulator's letter rather
/// than a bug report, so both entry points are pinned.
@Suite("Age gate")
struct AgeGateTests {

    @Test("Sixteen is the line, and it is inclusive")
    func theLine() {
        #expect(AgeGate.minimumAge == 16)
        #expect(AgeGate.tier(age: 15) == .tooYoung)
        #expect(AgeGate.tier(age: 16) == .adult)
        #expect(AgeGate.tier(age: 17) == .adult)
    }

    @Test("Nonsense is not adulthood")
    func nonsenseIsBlocked() {
        // A typed age is a text field, so it can hold anything. The failure that matters is
        // the one that opens the gate: an empty box parsed as zero, a stray minus, a number
        // nobody has ever been. All of them are `tooYoung`, which is the safe direction.
        #expect(AgeGate.tier(age: 0) == .tooYoung)
        #expect(AgeGate.tier(age: -1) == .tooYoung)
        #expect(AgeGate.tier(age: 999) == .tooYoung)
        #expect(AgeGate.tier(age: 131) == .tooYoung)
        #expect(AgeGate.tier(age: 130) == .adult)
    }

    @Test("A typed age and a birthdate agree")
    func bothEntryPointsAgree() {
        // Onboarding switched from a date wheel to a number, and the two must not be able to
        // disagree about the same person -- otherwise the gate depends on which screen was
        // shipped rather than on how old somebody is.
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_780_000_000)

        for years in [14, 15, 16, 17, 30] {
            guard let born = calendar.date(byAdding: .year, value: -years, to: now) else {
                Issue.record("could not build a birthdate")
                return
            }
            #expect(
                AgeGate.tier(bornOn: born, asOf: now, calendar: calendar) == AgeGate.tier(age: years),
                "a \(years)-year-old is judged differently by the two entry points"
            )
        }
    }

    @Test("The day before a sixteenth birthday is still too young")
    func theBoundaryDay() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        guard let sixteenth = calendar.date(byAdding: .year, value: -16, to: now),
              let dayAfter = calendar.date(byAdding: .day, value: 1, to: sixteenth)
        else {
            Issue.record("could not build the boundary dates")
            return
        }
        #expect(AgeGate.tier(bornOn: sixteenth, asOf: now, calendar: calendar) == .adult)
        #expect(AgeGate.tier(bornOn: dayAfter, asOf: now, calendar: calendar) == .tooYoung)
    }
}
