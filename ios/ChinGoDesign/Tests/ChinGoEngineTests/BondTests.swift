import Testing
@testable import ChinGoEngine

@Suite("Bond tiers")
struct BondTests {

    private func history(
        meetups: Int = 0, places: Int = 0, days: Int = 0, topFive: Bool = false
    ) -> BondHistory {
        BondHistory(meetups: meetups, distinctPlaces: places, daysKnown: days, mutualTopFive: topFive)
    }

    @Test("One catch is Met")
    func oneCatchIsMet() {
        #expect(Bond.tier(for: history(meetups: 1, places: 1, days: 1)) == .met)
    }

    @Test("Regular needs places as well as meetups")
    func regularNeedsPlaces() {
        // Ten meetups in a single place is a coworker, not a friend across your life.
        #expect(Bond.tier(for: history(meetups: 10, places: 1, days: 200)) == .met)
        #expect(Bond.tier(for: history(meetups: 3, places: 2, days: 5)) == .regular)
    }

    @Test("Crew needs time to have passed")
    func crewNeedsTime() {
        #expect(Bond.tier(for: history(meetups: 12, places: 6, days: 89)) == .regular)
        #expect(Bond.tier(for: history(meetups: 12, places: 6, days: 90)) == .crew)
    }

    @Test("Ride-or-die requires mutual top five")
    func rideRequiresMutual() {
        let almost = history(meetups: 40, places: 12, days: 400, topFive: false)
        #expect(Bond.tier(for: almost) == .crew)
        #expect(Bond.tier(for: history(meetups: 40, places: 12, days: 400, topFive: true)) == .rideOrDie)
    }

    @Test("Top tier has nothing left to ask for")
    func topTierHasNoRequirement() {
        #expect(Bond.nextTierRequirement(for: history(meetups: 40, places: 12, days: 400, topFive: true)) == nil)
    }

    @Test("A missing requirement is named, not hidden")
    func requirementIsNamed() {
        let r = Bond.nextTierRequirement(for: history(meetups: 1, places: 1, days: 1))
        #expect(r == "2 more meetups · 1 new place")
    }
}
