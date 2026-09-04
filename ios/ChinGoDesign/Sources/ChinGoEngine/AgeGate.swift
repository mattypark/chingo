import Foundation

/// The age gate.
///
/// Two decisions worth stating, because both are easy to get wrong in ways that only show up
/// later as a regulator's letter.
///
/// **Ask for a date, not for a yes.** "Are you 16 or over?" tells the person exactly which
/// answer unlocks the app, so it measures nothing. A neutral date entry — the shape Pokémon
/// GO and BeReal both use — at least records a real answer, and it is the pattern regulators
/// treat as a good-faith gate.
///
/// **Keep the tier, throw away the date.** A birthday is personal data ChinGo has no use for
/// after the check: it never shows an age, never sorts by it, never displays a birthday. So
/// the date is evaluated once and only the resulting tier is stored. Guideline 5.1.1(iii) is
/// explicit about collecting only what a feature actually needs, and the safest way to hold
/// data is to not hold it.
public enum AgeTier: Int, Sendable, CaseIterable {
    /// Below the floor. Cannot use the app.
    case tooYoung = 0
    /// Old enough for everything ChinGo does.
    case adult = 1
}

public enum AgeGate {
    /// Sixteen, not thirteen.
    ///
    /// ChinGo puts people in the same physical place as each other. That is a higher bar than
    /// a chat app, and the enforcement record backs it: the FTC banned NGL from serving
    /// under-18s outright, and Sendit was sued over data on under-13s. Sixteen is the line
    /// this product can defend.
    public static let minimumAge = 16

    /// Whole years elapsed, using the calendar rather than dividing seconds.
    ///
    /// A birthday is a calendar fact, not a duration: leap years, and the fact that "a year"
    /// is not a fixed number of seconds, both make the arithmetic version wrong for people
    /// born on the boundary — which is exactly the group a gate has to get right.
    public static func age(
        bornOn birthdate: Date,
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        calendar.dateComponents([.year], from: birthdate, to: now).year ?? 0
    }

    public static func tier(
        bornOn birthdate: Date,
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> AgeTier {
        age(bornOn: birthdate, asOf: now, calendar: calendar) >= minimumAge ? .adult : .tooYoung
    }

    /// The oldest date the picker should allow — today. A gate is not a place to be clever
    /// about the future.
    public static func latestSelectableBirthdate(asOf now: Date = .now) -> Date { now }
}
