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

    func award(_ event: XPEvent) {
        xp += event.amount
    }

    /// XP and the streak are derived from what actually happened, never stored as their own
    /// numbers. A stored total can drift from the events that produced it; a derived one
    /// cannot, and it means deleting a catch correctly un-earns what it earned.
    func recompute(from catches: [CatchRecord]) {
        let calendar = Calendar(identifier: .iso8601)

        xp = catches.reduce(0) { total, record in
            total + (record.kind == "snap" ? XPEvent.caught.amount : XPEvent.caught.amount / 4)
        }

        // Weeks containing a real-world meetup. A TAG is an introduction and does not count
        // — the streak is a record of time spent together, not of app usage.
        let weeks = catches
            .filter { $0.kind == "snap" }
            .compactMap { record -> Int? in
                let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.happenedAt)
                guard let year = parts.yearForWeekOfYear, let week = parts.weekOfYear else { return nil }
                return year * 53 + week
            }

        let now = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        guard let year = now.yearForWeekOfYear, let week = now.weekOfYear else { return }
        streakWeeks = Streak.current(weeksWithMeetup: weeks, currentWeek: year * 53 + week)
    }
}

struct NearbyPerson: Identifiable, Hashable {
    let id: String
    let handle: String
    /// Metres, already coarsened to the cell. Never a precise distance to a person.
    let approxMetres: Int
}
