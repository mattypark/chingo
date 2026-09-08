import Testing
import Foundation
@testable import ChinGoDesign

/// The whole mechanic is one date calculation, so it is worth pinning the edges: the ones
/// either side of nine in the morning, and the two days a year a day is not 24 hours long.
@Suite("Develop")
struct DevelopTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func at(_ y: Int, _ m: Int, _ d: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var parts = DateComponents()
        (parts.year, parts.month, parts.day, parts.hour, parts.minute) = (y, m, d, hour, minute)
        return calendar.date(from: parts)!
    }

    @Test("An evening catch develops the next morning")
    func eveningWaitsUntilMorning() {
        let developed = Develop.next(after: at(2026, 9, 8, 18, 14), calendar: calendar)
        #expect(developed == at(2026, 9, 9, 9))
    }

    /// It is already tomorrow at two in the morning, so it develops in seven hours, not
    /// thirty-one.
    @Test("A late-night catch develops that same morning")
    func lateNightDevelopsThatMorning() {
        let developed = Develop.next(after: at(2026, 9, 9, 2, 30), calendar: calendar)
        #expect(developed == at(2026, 9, 9, 9))
    }

    /// The edge that would make the feature look broken: a catch a minute before nine must
    /// not develop a minute later. This is the case the three-hour floor exists for.
    @Test("A catch just before nine waits a full day")
    func justBeforeNineWaitsADay() {
        let developed = Develop.next(after: at(2026, 9, 9, 8, 59), calendar: calendar)
        #expect(developed == at(2026, 9, 10, 9))
    }

    @Test("A catch just after nine develops the following morning")
    func justAfterNineWaitsADay() {
        let developed = Develop.next(after: at(2026, 9, 9, 9, 1), calendar: calendar)
        #expect(developed == at(2026, 9, 10, 9))
    }

    /// Spring forward: 8 March 2026, 02:00 does not exist in Los Angeles. Adding 86,400
    /// seconds to an evening catch would land at 10am, an hour late, and nobody would ever
    /// notice because it happens twice a year.
    @Test("Nine in the morning survives the clocks going forward")
    func springForward() {
        let developed = Develop.next(after: at(2026, 3, 7, 20), calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute, .day], from: developed)
        #expect(parts.hour == 9 && parts.minute == 0 && parts.day == 8)
    }

    @Test("And the clocks going back")
    func fallBack() {
        let developed = Develop.next(after: at(2026, 11, 1, 20), calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute, .day], from: developed)
        #expect(parts.hour == 9 && parts.minute == 0 && parts.day == 2)
    }

    @Test("Always in the future, whatever hour it is asked at")
    func alwaysAhead() {
        for hour in 0..<24 {
            let moment = at(2026, 7, 14, hour, 30)
            #expect(Develop.next(after: moment, calendar: calendar) > moment)
        }
    }

    // MARK: Reading it back

    /// Every photo that existed before this rule shipped has no develop time. Hiding them
    /// retroactively would be a bug wearing a feature's clothes.
    @Test("A photo with no develop time is already developed")
    func nilIsDeveloped() {
        #expect(Develop.isDeveloped(nil))
    }

    @Test("Developed exactly at the moment it is due, not a tick later")
    func inclusiveAtTheBoundary() {
        let due = at(2026, 9, 9, 9)
        #expect(!Develop.isDeveloped(due, now: due.addingTimeInterval(-1)))
        #expect(Develop.isDeveloped(due, now: due))
        #expect(Develop.isDeveloped(due, now: due.addingTimeInterval(1)))
    }

    @Test("The wait reads in hours, then minutes, then stops")
    func spokenWait() {
        let due = at(2026, 9, 9, 9)
        #expect(Develop.spokenWait(until: due, now: at(2026, 9, 8, 19)) == "in 14 hours")
        #expect(Develop.spokenWait(until: due, now: at(2026, 9, 9, 8)) == "in 1 hour")
        #expect(Develop.spokenWait(until: due, now: at(2026, 9, 9, 8, 20)) == "in 40 minutes")
        #expect(Develop.spokenWait(until: due, now: due) == nil)
        #expect(Develop.spokenWait(until: nil) == nil)
    }

    /// Never "in 0 minutes". The last minute rounds up rather than reading as a stuck clock.
    @Test("The final seconds still say a minute")
    func neverZero() {
        let due = at(2026, 9, 9, 9)
        #expect(Develop.spokenWait(until: due, now: due.addingTimeInterval(-20)) == "in 1 minute")
    }
}
