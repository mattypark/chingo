import Foundation

/// What earns XP, and how much.
///
/// Reconnecting after a long gap is the largest single award in the game. That is not a
/// balance decision, it is the product thesis: the app exists so you stop losing people.
public enum XPEvent: Sendable, Equatable {
    case caught
    case caughtInNewCity
    case memoryRevisited
    /// Reconnected with someone last seen `daysSince` ago.
    case reconnected(daysSince: Int)
    case setCompleted(size: Int)

    public var amount: Int {
        switch self {
        case .caught: 40
        case .caughtInNewCity: 150
        case .memoryRevisited: 25
        case let .reconnected(days):
            // Scales with how far gone the friendship was, because bringing back someone
            // you have not seen in two years is the hardest and best thing the app can
            // cause. Capped so it stays a reward and never becomes a farm.
            min(600, 60 + days * 2)
        case let .setCompleted(size): 50 * size
        }
    }
}

public enum Progression {
    /// Levels get further apart, but never punishingly: a quadratic curve, not exponential.
    /// Level n begins at 100 · (n − 1)².
    public static func xpRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 100 * (level - 1) * (level - 1)
    }

    public static func level(forXP xp: Int) -> Int {
        guard xp > 0 else { return 1 }
        return Int((Double(xp) / 100).squareRoot()) + 1
    }

    /// 0…1 through the current level, for the ring around the avatar.
    public static func progressWithinLevel(xp: Int) -> Double {
        let level = level(forXP: xp)
        let floorXP = xpRequired(forLevel: level)
        let ceilXP = xpRequired(forLevel: level + 1)
        guard ceilXP > floorXP else { return 0 }
        return Double(xp - floorXP) / Double(ceilXP - floorXP)
    }
}

/// How long you have kept it up, counted in days — and, still, in weeks.
///
/// **This file used to argue against daily streaks and Matthew overruled it.** The argument is
/// kept because the risk it names is real and the mitigations below exist to answer it: it
/// said Duolingo's friend streaks lift completion ~22%, so the mechanic works, but Snapchat's
/// daily version is documented internally as causing "mass psychosis" in teenagers — and that
/// a streak you keep by living is worth having while a streak you keep by opening an app is a
/// leash. It concluded that the app should count weeks containing a real meetup.
///
/// The decision is days. What keeps that from being the leash the old comment described is
/// that the *unit* was never the dangerous part — the punishment was:
///
/// - **What counts is still meeting somebody**, never opening the app. This is the half of the
///   original argument that survives intact, and it is the half that matters.
/// - **Freezes are finite.** Finch ships two repair hammers, and finite is what makes spending
///   one a decision rather than an undo. `repairable` says when one would help.
/// - **There is no public break, and no scolding on return.** A lapsed streak is announced to
///   nobody, and coming back is greeted. Guilt is what turns a counter into a leash.
/// - **Zero is not displayed.** A screen that says "0 days" in the corner is the shame with
///   extra steps.
///
/// The week counter stays. It is the honest long-horizon answer — "weeks you saw somebody" is
/// a truer picture of a year than a day count that a fortnight's holiday resets — and both now
/// share one walk, so the two cannot disagree about what a run is.
public enum Streak {

    /// The walk both counters do: how far back an unbroken run of ordinals reaches.
    ///
    /// Unit-agnostic on purpose. It takes opaque `Int` ordinals and steps by one, so the same
    /// code counts ISO weeks and calendar days and cannot drift between them.
    ///
    /// The end not being done yet is not a broken streak — it is Tuesday, or it is this week.
    private static func run(over covered: Set<Int>, endingAt end: Int) -> Int {
        var cursor = covered.contains(end) ? end : end - 1
        var count = 0
        while covered.contains(cursor) {
            count += 1
            cursor -= 1
        }
        return count
    }

    /// `weeksWithMeetup` are ISO week ordinals, unsorted and possibly duplicated.
    public static func current(weeksWithMeetup: [Int], currentWeek: Int) -> Int {
        run(over: Set(weeksWithMeetup), endingAt: currentWeek)
    }

    /// Consecutive days ending today — or yesterday, if today has not happened yet.
    ///
    /// `daysWithMeetup` and `frozenDays` are day ordinals, unsorted and possibly duplicated.
    /// They are merged before the walk rather than special-cased inside it, so a frozen day
    /// genuinely *is* a day rather than a hole the loop learns to step over. That is also what
    /// makes a freeze spent on a day you later meet somebody harmless instead of a double
    /// count.
    public static func current(daysWithMeetup: [Int], frozenDays: [Int] = [], today: Int) -> Int {
        run(over: Set(daysWithMeetup).union(frozenDays), endingAt: today)
    }

    /// The days a repair would have to cover to reconnect the streak to today.
    ///
    /// Empty when there is nothing to repair — either the streak is intact, or it was already
    /// broken so long ago that `limit` freezes could not bridge it. Both of those are the same
    /// answer to the only question the sheet asks: is there a button to offer.
    ///
    /// Returned oldest first, and never including today: today is still yours to earn, and
    /// spending a freeze on it would buy something you have all day to get for free.
    public static func repairable(
        daysWithMeetup: [Int],
        frozenDays: [Int] = [],
        today: Int,
        limit: Int
    ) -> [Int] {
        guard limit > 0 else { return [] }

        let covered = Set(daysWithMeetup).union(frozenDays)
        // Intact already: yesterday or today is covered, so nothing is missing behind them.
        guard !covered.contains(today), !covered.contains(today - 1) else { return [] }

        // The most recent day that did count. Without one there is no streak to reconnect --
        // a first-ever streak is started by going outside, not by spending a repair.
        guard let last = covered.max(), last < today - 1 else { return [] }

        let gap = Array((last + 1)..<today)
        return gap.count <= limit ? gap : []
    }
}
