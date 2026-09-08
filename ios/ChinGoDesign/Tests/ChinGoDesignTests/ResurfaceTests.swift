import Testing
import Foundation
@testable import ChinGoEngine

@Suite("Resurfacing a memory")
struct ResurfaceTests {

    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func candidate(
        _ id: String = "a",
        metres: Double = 40,
        ageHours: Double = 72,
        surfacedHoursAgo: Double? = nil
    ) -> Resurface.Candidate {
        Resurface.Candidate(
            id: id,
            metres: metres,
            happenedOn: now.addingTimeInterval(-ageHours * 3600),
            lastSurfaced: surfacedHoursAgo.map { now.addingTimeInterval(-$0 * 3600) }
        )
    }

    @Test("A memory you just made does not tell you about itself")
    func todayStaysQuiet() {
        // The failure this prevents: photograph somebody, the memory lands at your feet, and
        // the app immediately announces that you met them here while they are still standing
        // in front of you.
        #expect(Resurface.isEligible(candidate(ageHours: 0.1), now: now) == false)
        #expect(Resurface.isEligible(candidate(ageHours: 11.9), now: now) == false)
        #expect(Resurface.isEligible(candidate(ageHours: 12.1), now: now))
    }

    @Test("The same corner does not fire twice on one walk")
    func cooldownHolds() {
        #expect(Resurface.isEligible(candidate(surfacedHoursAgo: 1), now: now) == false)
        #expect(Resurface.isEligible(candidate(surfacedHoursAgo: 19.9), now: now) == false)
        #expect(Resurface.isEligible(candidate(surfacedHoursAgo: 20.1), now: now))
    }

    @Test("The cooldown is short enough to drift across the day")
    func cooldownDoesNotLockToAnHour() {
        // A full day would pin a commute memory to whichever leg of the journey it first fired
        // on: the return trip is always inside the window and the next morning is always a few
        // minutes early, so it can never move.
        #expect(Resurface.cooldown < 60 * 60 * 24)
    }

    @Test("Out of range is not a candidate at all")
    func rangeGates() {
        #expect(Resurface.isEligible(candidate(metres: Geo.memoryRadiusMetres - 1), now: now))
        #expect(Resurface.isEligible(candidate(metres: Geo.memoryRadiusMetres + 1), now: now) == false)
    }

    @Test("Nearest wins, and only one is ever picked")
    func nearestWins() {
        let picked = Resurface.pick(
            from: [candidate("far", metres: 120), candidate("near", metres: 20)],
            now: now
        )
        #expect(picked?.id == "near")
    }

    @Test("A tie goes to the memory you had stopped thinking about")
    func tiesFavourTheOlder() {
        let picked = Resurface.pick(
            from: [candidate("recent", metres: 30, ageHours: 20),
                   candidate("ancient", metres: 30, ageHours: 5_000)],
            now: now
        )
        #expect(picked?.id == "ancient")
    }

    @Test("Nothing eligible means nothing shown")
    func silenceIsAnAnswer() {
        #expect(Resurface.pick(from: [], now: now) == nil)
        #expect(Resurface.pick(from: [candidate(ageHours: 1)], now: now) == nil)
        #expect(Resurface.pick(from: [candidate(metres: 400)], now: now) == nil)
    }
}
