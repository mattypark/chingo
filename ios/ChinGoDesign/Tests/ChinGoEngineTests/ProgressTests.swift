import Testing
@testable import ChinGoEngine

@Suite("Progression")
struct ProgressTests {

    @Test("Level curve and its inverse agree")
    func curveRoundTrips() {
        for level in 1...40 {
            let floorXP = Progression.xpRequired(forLevel: level)
            #expect(Progression.level(forXP: floorXP) == level)
            #expect(Progression.level(forXP: floorXP + 1) == level)
        }
    }

    @Test("Fresh account is level one at zero progress")
    func freshAccount() {
        #expect(Progression.level(forXP: 0) == 1)
        #expect(Progression.progressWithinLevel(xp: 0) == 0)
    }

    @Test("Progress within a level stays in bounds")
    func progressInBounds() {
        for xp in stride(from: 0, through: 20_000, by: 137) {
            let p = Progression.progressWithinLevel(xp: xp)
            #expect(p >= 0 && p < 1)
        }
    }

    @Test("Reconnecting outweighs catching, and is capped")
    func reconnectDominates() {
        #expect(XPEvent.reconnected(daysSince: 365).amount > XPEvent.caught.amount)
        #expect(XPEvent.reconnected(daysSince: 10_000).amount == 600)
    }

    @Test("Streak survives a week that has not happened yet")
    func streakSurvivesCurrentWeek() {
        // Weeks 10, 11, 12 done; it is now week 13 and nothing has happened yet. That is
        // Tuesday, not a broken streak.
        #expect(Streak.current(weeksWithMeetup: [10, 11, 12], currentWeek: 13) == 3)
        #expect(Streak.current(weeksWithMeetup: [10, 11, 12], currentWeek: 12) == 3)
        // A genuinely missed week ends it.
        #expect(Streak.current(weeksWithMeetup: [10, 11, 12], currentWeek: 14) == 0)
    }
}
