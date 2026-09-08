import CoreLocation
import Foundation
import Observation
import ChinGoEngine

/// Session state for the map screen — the things that are true about this run of the app
/// rather than about the person's history.
///
/// Friends, catches and memories all live in SwiftData and are read with `@Query`. What is
/// left here is genuinely ephemeral: whether you are currently findable, and what the world
/// is showing you right now.
@MainActor
@Observable
final class MapState {

    var xp: Int = 0
    var level: Int { Progression.level(forXP: xp) }
    var levelProgress: Double { Progression.progressWithinLevel(xp: xp) }
    var streakWeeks: Int = 0
    /// Consecutive days ending today. What the pill and the profile now count.
    var streakDays: Int = 0
    /// The days a repair would have to cover to reconnect the streak, oldest first, or empty
    /// when there is nothing to offer. See `Streak.repairable`.
    var repairableDays: [Int] = []
    /// Today, as a day ordinal. Held so the sheet can record a freeze in the same units the
    /// engine counts in without doing its own calendar arithmetic.
    var today: Int = 0
    /// Days since you last met somebody, or nil if you never have. What the bear runs on.
    var daysSinceMeetup: Int?

    /// Off by default, and per-session. Being findable is something you switch on when you
    /// go out, not a property of having installed the app.
    var discoverable: Bool = false

    /// Who the presence gate has decided you may see. Empty until stage 5 wires it to real
    /// presence; the gate itself already exists and is tested in `ChinGoEngine.Presence`.
    var nearby: [NearbyPerson] = []

    /// The catch button is live only when there is genuinely someone to catch — except in
    /// debug, where there is no second phone to test against.
    var canCatch: Bool {
        #if DEBUG
        return true
        #else
        return discoverable && !nearby.isEmpty
        #endif
    }

    /// Everything here is still derived from what actually happened — with one deliberate
    /// exception, passed in rather than accumulated.
    ///
    /// The original rule was that XP and the streak are never stored as their own numbers,
    /// because a stored total drifts from the events that produced it while a derived one
    /// cannot, and because deleting a catch should correctly un-earn what it earned. That is
    /// still true of everything derivable from a `CatchRecord`.
    ///
    /// It is not true of everything. A spent freeze and a revisited memory are events that
    /// leave no `CatchRecord` behind, so they cannot be recomputed from one — they are state,
    /// they live on `MeRecord`, and they arrive here as `bonusXP` and `frozenDays`. The rule
    /// narrows rather than falls: nothing is *accumulated* in this class, and every number
    /// below is a pure function of what it was handed.
    ///
    /// There used to be an `award(_:)` that did `xp +=` onto the same property this method
    /// overwrites. It was called from two places and was wrong in both: the catch it awarded
    /// had already been counted here, so 40 XP was double-counted and then silently deleted on
    /// the next recompute — and a revisited memory's 25 XP was *always* deleted, because there
    /// is no term for memories in a sum over catches. Nobody noticed because the visible number
    /// was correct again a moment later.
    func recompute(from catches: [CatchRecord], bonusXP: Int = 0, frozenDays: [Int] = []) {
        let calendar = Calendar(identifier: .iso8601)

        xp = bonusXP + catches.reduce(0) { total, record in
            total + (record.kind == "snap" ? XPEvent.caught.amount : XPEvent.caught.amount / 4)
        }

        // A TAG is an introduction and does not count — the streak is a record of time spent
        // together, not of app usage. Both counters agree on that.
        let meetups = catches.filter { $0.kind == "snap" }

        let weeks = meetups.compactMap { record -> Int? in
            let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.happenedAt)
            guard let year = parts.yearForWeekOfYear, let week = parts.weekOfYear else { return nil }
            return year * 53 + week
        }

        let now = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        if let year = now.yearForWeekOfYear, let week = now.weekOfYear {
            streakWeeks = Streak.current(weeksWithMeetup: weeks, currentWeek: year * 53 + week)
        }

        // Days are ordinals rather than dates from here on. The conversion stays in this
        // class, as the week one already does, so `ChinGoEngine` never sees a `Calendar`.
        today = Self.dayOrdinal(of: .now, in: calendar)
        let days = meetups.map { Self.dayOrdinal(of: $0.happenedAt, in: calendar) }

        // Real meetups only, and deliberately not `frozenDays`. A freeze keeps the counter
        // alive; it does not mean you saw anybody, and a bear cheered up by spending a repair
        // would be a companion you can buy off.
        daysSinceMeetup = days.max().map { today - $0 }

        streakDays = Streak.current(daysWithMeetup: days, frozenDays: frozenDays, today: today)
        repairableDays = Streak.repairable(
            daysWithMeetup: days,
            frozenDays: frozenDays,
            today: today,
            limit: MeRecord.freezeAllowance
        )
    }

    /// A date as a day number that increases by one each midnight.
    ///
    /// `ordinality(of: .day, in: .era)` rather than day-of-year plus a year term: a run that
    /// crosses New Year has to be one continuous sequence, and `year * 366 + dayOfYear` leaves
    /// a hole at every turn of the year that reads as a broken streak on 1 January.
    nonisolated static func dayOrdinal(of date: Date, in calendar: Calendar) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }
}

struct NearbyPerson: Identifiable, Hashable {
    let id: String
    let handle: String
    /// Metres, already coarsened to the cell. Never a precise distance to a person.
    let approxMetres: Int

    /// Where their bear stands.
    ///
    /// Live only. This is the field that changes the privacy model -- `Presence.swift` said
    /// precise position is never exposed, and drawing somebody standing on a street is
    /// exactly that. It is deliberate, it is limited to the public server while both people
    /// are discoverable, and nothing about it is written down. The contract and the argument
    /// are in docs/HANDOFF-BACKEND.md; the engine's rule is the backend session's to rewrite.
    let coordinate: CLLocationCoordinate2D
    /// Their bear's colour, as an index into `Accent.all`. Never a hex -- a colour saved in a
    /// database survives a rebrand it should not.
    let accent: Int
    /// Which way they are walking, or nil when standing still. Drives idle versus walk.
    let course: CLLocationDirection?
    /// Their picture, if they set one. Nil is the common case and means show the bear.
    let portraitFile: String?

    init(
        id: String,
        handle: String,
        approxMetres: Int,
        coordinate: CLLocationCoordinate2D,
        accent: Int = 0,
        course: CLLocationDirection? = nil,
        portraitFile: String? = nil
    ) {
        self.id = id
        self.handle = handle
        self.approxMetres = approxMetres
        self.coordinate = coordinate
        self.accent = accent
        self.course = course
        self.portraitFile = portraitFile
    }

    static func == (a: NearbyPerson, b: NearbyPerson) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
