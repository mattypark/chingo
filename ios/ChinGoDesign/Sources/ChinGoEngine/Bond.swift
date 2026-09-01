import Foundation

/// How close two people actually are, derived only from things that happened.
///
/// Tiers are **earned, never bought** — no cosmetic, purchase or subscription may reach
/// this file. They are also **symmetric**: `tier(for:)` is computed from a shared history
/// object, so you cannot be someone's Ride-or-die unless they are yours. That kills
/// one-sided flexing and removes any reason to farm strangers.
public enum BondTier: Int, CaseIterable, Sendable, Comparable {
    case met = 0
    case regular = 1
    case crew = 2
    case rideOrDie = 3

    public static func < (lhs: BondTier, rhs: BondTier) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .met: "Met"
        case .regular: "Regular"
        case .crew: "Crew"
        case .rideOrDie: "Ride-or-die"
        }
    }
}

/// The shared, symmetric record of a friendship. Both people see the same numbers.
public struct BondHistory: Sendable, Equatable {
    /// Confirmed in-person catches. A TAG is not a meetup.
    public let meetups: Int
    /// Distinct places those meetups happened. Seeing someone in five places is a
    /// different relationship from seeing them fifty times in one.
    public let distinctPlaces: Int
    /// Days since the first catch.
    public let daysKnown: Int
    /// True only when each person is in the other's top five by meetups.
    public let mutualTopFive: Bool

    public init(meetups: Int, distinctPlaces: Int, daysKnown: Int, mutualTopFive: Bool) {
        self.meetups = meetups
        self.distinctPlaces = distinctPlaces
        self.daysKnown = daysKnown
        self.mutualTopFive = mutualTopFive
    }
}

public enum Bond {
    /// Thresholds live in one place so the ladder can be retuned without hunting call sites.
    public enum Threshold {
        public static let regularMeetups = 3
        public static let regularPlaces = 2

        public static let crewMeetups = 10
        public static let crewPlaces = 5
        public static let crewDays = 90

        public static let rideMeetups = 25
        public static let rideDays = 365
    }

    public static func tier(for h: BondHistory) -> BondTier {
        if h.meetups >= Threshold.rideMeetups,
           h.daysKnown >= Threshold.rideDays,
           h.mutualTopFive {
            return .rideOrDie
        }
        if h.meetups >= Threshold.crewMeetups,
           h.distinctPlaces >= Threshold.crewPlaces,
           h.daysKnown >= Threshold.crewDays {
            return .crew
        }
        if h.meetups >= Threshold.regularMeetups,
           h.distinctPlaces >= Threshold.regularPlaces {
            return .regular
        }
        return .met
    }

    /// What is still missing before the next tier, phrased for the card back. Nil at the top.
    ///
    /// Shown because the progression is deterministic: you always know why you are where
    /// you are, which is the whole difference between this and a slot machine.
    public static func nextTierRequirement(for h: BondHistory) -> String? {
        switch tier(for: h) {
        case .met:
            let m = max(0, Threshold.regularMeetups - h.meetups)
            let p = max(0, Threshold.regularPlaces - h.distinctPlaces)
            return phrase(meetups: m, places: p, days: 0)
        case .regular:
            let m = max(0, Threshold.crewMeetups - h.meetups)
            let p = max(0, Threshold.crewPlaces - h.distinctPlaces)
            let d = max(0, Threshold.crewDays - h.daysKnown)
            return phrase(meetups: m, places: p, days: d)
        case .crew:
            let m = max(0, Threshold.rideMeetups - h.meetups)
            let d = max(0, Threshold.rideDays - h.daysKnown)
            let base = phrase(meetups: m, places: 0, days: d)
            guard h.mutualTopFive else {
                return base.map { "\($0), and each other's top five" } ?? "Each other's top five"
            }
            return base
        case .rideOrDie:
            return nil
        }
    }

    private static func phrase(meetups: Int, places: Int, days: Int) -> String? {
        var parts: [String] = []
        if meetups > 0 { parts.append("\(meetups) more \(meetups == 1 ? "meetup" : "meetups")") }
        if places > 0 { parts.append("\(places) new \(places == 1 ? "place" : "places")") }
        if days > 0 { parts.append("\(days) more \(days == 1 ? "day" : "days")") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
