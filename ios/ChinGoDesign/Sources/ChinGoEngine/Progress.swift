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

/// Weeks that contained at least one real-world meetup.
///
/// Deliberately not daily, and deliberately not app-opens. Duolingo's friend streaks lift
/// completion ~22%, so the mechanic works — but Snapchat's daily version is documented
/// internally as causing "mass psychosis" in teenagers. A streak you keep by living is
/// worth having; a streak you keep by opening an app is a leash.
///
/// There is also no public break: a lapsed streak is never announced to anyone.
public enum Streak {
    /// `weeksWithMeetup` are ISO week ordinals, unsorted and possibly duplicated.
    public static func current(weeksWithMeetup: [Int], currentWeek: Int) -> Int {
        let weeks = Set(weeksWithMeetup)
        // This week not being done yet is not a broken streak — it is Tuesday.
        var cursor = weeks.contains(currentWeek) ? currentWeek : currentWeek - 1
        var count = 0
        while weeks.contains(cursor) {
            count += 1
            cursor -= 1
        }
        return count
    }
}
