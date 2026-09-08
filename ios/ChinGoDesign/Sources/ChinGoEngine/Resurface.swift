import Foundation

/// Which memory, if any, is worth mentioning as you walk past it.
///
/// The map already draws every nearby memory as a pin, so this is not "what is around" — it
/// is the much narrower question of what deserves to interrupt. Three rules, and each one
/// exists because without it the feature turns into noise in a specific, predictable way.
///
/// It is here rather than in the app because it is entirely a rule about time and distance,
/// and rules about when to interrupt somebody are exactly the thing worth being able to test
/// without a phone in the loop.
public enum Resurface {

    /// How long a memory has to have existed before it can resurface.
    ///
    /// Without this the feature fires the instant you make a memory. You photograph somebody,
    /// the memory is written at your feet, and the app immediately tells you that you met them
    /// here — which is both useless and slightly unsettling, because you are still standing
    /// next to them. Overnight is the natural floor: this is a thing that reminds you of
    /// another day, so it should not be able to talk about today.
    public static let minimumAge: TimeInterval = 60 * 60 * 12

    /// How long a memory stays quiet after it has surfaced.
    ///
    /// Twenty hours rather than twenty-four, deliberately. A day-long cooldown means a memory
    /// on your commute can only ever fire on the leg of the journey it first fired on — the
    /// return trip is always inside the window, and the morning after is a few minutes early.
    /// Slightly under a day lets it drift across the day instead of locking to one hour of it.
    public static let cooldown: TimeInterval = 60 * 60 * 20

    /// Everything the rule needs to know about one memory. Deliberately not the stored model:
    /// the rule is about time and distance and should not be able to reach anything else.
    public struct Candidate: Equatable, Sendable {
        public let id: String
        public let metres: Double
        public let happenedOn: Date
        public let lastSurfaced: Date?

        public init(id: String, metres: Double, happenedOn: Date, lastSurfaced: Date?) {
            self.id = id
            self.metres = metres
            self.happenedOn = happenedOn
            self.lastSurfaced = lastSurfaced
        }
    }

    /// Whether one memory is allowed to speak up right now.
    public static func isEligible(_ candidate: Candidate, now: Date = .now) -> Bool {
        guard candidate.metres <= Geo.memoryRadiusMetres else { return false }
        guard now.timeIntervalSince(candidate.happenedOn) >= minimumAge else { return false }
        guard let last = candidate.lastSurfaced else { return true }
        return now.timeIntervalSince(last) >= cooldown
    }

    /// The one to mention, or nothing.
    ///
    /// **Nearest, not oldest and not newest.** A city block can hold several memories, and the
    /// only one you can act on is the one you are standing closest to — walking two streets
    /// back to a better story is not a thing anybody does. Ties break on the older memory,
    /// because the whole point of resurfacing is the ones you had stopped thinking about.
    ///
    /// Returns at most one. Two of these on screen at once is a feed, and a feed is the thing
    /// this app is meant to be the alternative to.
    public static func pick(from candidates: [Candidate], now: Date = .now) -> Candidate? {
        candidates
            .filter { isEligible($0, now: now) }
            .min { left, right in
                left.metres == right.metres
                    ? left.happenedOn < right.happenedOn
                    : left.metres < right.metres
            }
    }
}
