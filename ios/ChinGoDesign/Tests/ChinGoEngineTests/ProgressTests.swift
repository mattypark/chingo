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

// MARK: - The day streak

/// Days, freezes, and what a repair can reach.
///
/// Ordinals are plain integers here rather than real dates on purpose: the engine never sees a
/// `Date`, so neither should its tests. 100 is "today" throughout, which keeps every case
/// readable as an offset from it.
@Suite("Streak in days")
struct DayStreakTests {

    @Test("Today not being done yet is not a broken streak")
    func todayIsStillOpen() {
        // Met somebody on each of the three days before today, nothing yet today.
        #expect(Streak.current(daysWithMeetup: [97, 98, 99], today: 100) == 3)
        // And meeting somebody today extends it rather than restarting it.
        #expect(Streak.current(daysWithMeetup: [97, 98, 99, 100], today: 100) == 4)
    }

    @Test("A missed day ends the run, however long it was")
    func oneMissedDayBreaksIt() {
        // 98 is missing, so the run reaches back only as far as 99.
        #expect(Streak.current(daysWithMeetup: [95, 96, 97, 99], today: 100) == 1)
    }

    @Test("Two days with nothing in between is no streak at all")
    func lapsedIsZero() {
        #expect(Streak.current(daysWithMeetup: [90, 91, 92], today: 100) == 0)
    }

    @Test("A freeze counts as a day you were there")
    func freezeFillsTheHole() {
        // Without the freeze this is 1; the freeze on 98 joins the two halves.
        #expect(Streak.current(daysWithMeetup: [96, 97, 99], frozenDays: [98], today: 100) == 4)
    }

    @Test("A freeze on a day you also met somebody counts once")
    func freezeDoesNotDoubleCount() {
        #expect(Streak.current(daysWithMeetup: [97, 98, 99], frozenDays: [98], today: 100) == 3)
    }

    @Test("Duplicated and unsorted days are the same streak")
    func inputOrderDoesNotMatter() {
        #expect(Streak.current(daysWithMeetup: [99, 97, 98, 99, 97], today: 100) == 3)
    }

    @Test("An empty history is zero, not a crash")
    func nothingYet() {
        #expect(Streak.current(daysWithMeetup: [], today: 100) == 0)
    }
}

@Suite("Repairing a streak")
struct StreakRepairTests {

    @Test("An intact streak has nothing to repair")
    func intactOffersNothing() {
        #expect(Streak.repairable(daysWithMeetup: [98, 99], today: 100, limit: 2).isEmpty)
        // Including the case where today is already done.
        #expect(Streak.repairable(daysWithMeetup: [99, 100], today: 100, limit: 2).isEmpty)
    }

    @Test("One missed day is one day to repair")
    func singleGap() {
        // 99 is missing; 98 was the last day that counted.
        #expect(Streak.repairable(daysWithMeetup: [96, 97, 98], today: 100, limit: 2) == [99])
    }

    @Test("A gap wider than the freezes left is not offered at all")
    func gapBeyondReach() {
        // Four days missing and two freezes cannot bridge it, so there is no button.
        #expect(Streak.repairable(daysWithMeetup: [95], today: 100, limit: 2).isEmpty)
        // The same gap with enough freezes is offered whole, oldest first.
        #expect(Streak.repairable(daysWithMeetup: [95], today: 100, limit: 4) == [96, 97, 98, 99])
    }

    @Test("Today is never something you spend a freeze on")
    func todayIsNotForSale() {
        let days = Streak.repairable(daysWithMeetup: [96, 97], today: 100, limit: 3)
        #expect(!days.contains(100))
        #expect(days == [98, 99])
    }

    @Test("Nothing to reconnect to means nothing to repair")
    func noStreakToSave() {
        // A first-ever streak is started by going outside, not by spending a repair.
        #expect(Streak.repairable(daysWithMeetup: [], today: 100, limit: 2).isEmpty)
    }

    @Test("With no freezes left there is no offer, whatever the gap")
    func outOfFreezes() {
        #expect(Streak.repairable(daysWithMeetup: [98], today: 100, limit: 0).isEmpty)
    }

    @Test("A repair actually reconnects the streak it was offered for")
    func repairingRestoresTheRun() {
        // The whole point, checked end to end rather than in two halves that agree by luck.
        let history = [96, 97, 98]
        let gap = Streak.repairable(daysWithMeetup: history, today: 100, limit: 2)
        #expect(Streak.current(daysWithMeetup: history, today: 100) == 0)
        #expect(Streak.current(daysWithMeetup: history, frozenDays: gap, today: 100) == 4)
    }
}

@Suite("Weeks and days agree")
struct StreakUnitTests {

    @Test("Both counters walk the same way over the same ordinals")
    func oneWalkTwoUnits() {
        // The week and day counters share `run`, so the same shape of history has to give the
        // same answer in either unit. If these ever diverge, one of them grew its own loop.
        let ordinals = [40, 41, 43]
        #expect(
            Streak.current(weeksWithMeetup: ordinals, currentWeek: 44)
                == Streak.current(daysWithMeetup: ordinals, today: 44)
        )
    }
}
