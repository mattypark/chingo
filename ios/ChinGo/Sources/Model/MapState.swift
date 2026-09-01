import Foundation
import Observation
import ChinGoEngine

/// Everything the map screen renders, in one observable place.
///
/// Seeded with mock data so the whole interface is drivable before Supabase, MapLibre or
/// auth exist. Stage 4 and 5 swap the seeding for real sources; nothing in the views has
/// to change.
@MainActor
@Observable
final class MapState {

    // MARK: You

    var xp: Int = 1_480
    var level: Int { Progression.level(forXP: xp) }
    var levelProgress: Double { Progression.progressWithinLevel(xp: xp) }
    /// Weeks that contained a real-world meetup. Never days, never app-opens.
    var streakWeeks: Int = 6

    /// Off by default, and per-session. Being findable is something you switch on when you
    /// go out, not a property of having installed the app.
    var discoverable: Bool = false

    // MARK: The world

    var nearby: [NearbyPerson] = []
    var memories: [MemoryPin] = []

    /// The catch button is live only when there is genuinely someone to catch. A control
    /// that is always available teaches people that pressing it means nothing.
    var canCatch: Bool { discoverable && !nearby.isEmpty }

    init() { seed() }

    func toggleDiscoverable() {
        discoverable.toggle()
        seed()
    }

    private func seed() {
        guard discoverable else {
            nearby = []
            // Memories are yours alone and do not depend on being findable — they are the
            // half of the app that works with the world switched off.
            memories = MemoryPin.samples
            return
        }
        nearby = NearbyPerson.samples
        memories = MemoryPin.samples
    }
}

/// Someone the presence gate has decided you may see.
struct NearbyPerson: Identifiable, Hashable {
    let id: String
    let handle: String
    /// Metres, already coarsened to the cell. Never a precise distance to a person.
    let approxMetres: Int
    let isNewFace: Bool

    static let samples: [NearbyPerson] = [
        .init(id: "n1", handle: "jae", approxMetres: 40, isNewFace: true),
        .init(id: "n2", handle: "mira", approxMetres: 120, isNewFace: false),
        .init(id: "n3", handle: "toby", approxMetres: 260, isNewFace: true),
    ]
}

/// A place where something already happened.
struct MemoryPin: Identifiable, Hashable {
    let id: String
    let friendHandle: String
    let place: String
    let date: Date
    /// Screen-space position for the placeholder map. Replaced by real coordinates at
    /// stage 4.
    let x: Double
    let y: Double

    var agoDescription: String {
        let years = Calendar.current.dateComponents([.year], from: date, to: .now).year ?? 0
        if years >= 1 { return "\(years) year\(years == 1 ? "" : "s") ago" }
        let months = Calendar.current.dateComponents([.month], from: date, to: .now).month ?? 0
        return months <= 1 ? "last month" : "\(months) months ago"
    }

    static let samples: [MemoryPin] = [
        .init(id: "m1", friendHandle: "sunny", place: "Dolores Park",
              date: .now.addingTimeInterval(-60 * 60 * 24 * 1_100), x: 0.24, y: 0.34),
        .init(id: "m2", friendHandle: "jae", place: "the ramen place",
              date: .now.addingTimeInterval(-60 * 60 * 24 * 260), x: 0.74, y: 0.28),
        .init(id: "m3", friendHandle: "mira", place: "Ocean Beach",
              date: .now.addingTimeInterval(-60 * 60 * 24 * 640), x: 0.62, y: 0.58),
    ]
}
