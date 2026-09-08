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
