#if DEBUG
import Foundation
import SwiftData
import ChinGoEngine

/// Debug-only seeding, behind a launch argument.
///
/// The app is local-first and starts genuinely empty, which is correct but makes the
/// populated screens impossible to look at without spending ten minutes catching people by
/// hand every time the store is wiped. `-seedDemo` fills it; `-openAlbum` lands on the
/// album.
///
/// Wrapped in `#if DEBUG` and gated on an argument, so it cannot run in a shipped build and
/// does not run in a normal debug launch either.
enum DemoSeed {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedDemo")
    }

    static var opensAlbum: Bool {
        opens == "album"
    }

    /// Which surface to land on, from `-open <name>`.
    ///
    /// Screenshotting a sheet otherwise means tapping through to it, which cannot be done
    /// from the command line — so every surface added has to be taken on trust, which is
    /// exactly how a screen ships with its own close button clipped off the bottom.
    static var opens: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-open"), args.index(after: i) < args.endIndex else {
            return nil
        }
        return args[args.index(after: i)]
    }

    /// `-resetOnboarding` clears the completion stamp so first run can be walked again
    /// without deleting the app and losing everything else in the store.
    static var resetsOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-resetOnboarding")
    }

    static func populate(_ context: ModelContext) {
        if resetsOnboarding {
            let existing = (try? context.fetch(FetchDescriptor<MeRecord>())) ?? []
            for record in existing { record.onboardedAt = nil }
            try? context.save()
        }

        guard isRequested else { return }

        // Identity is seeded on its own. Gating it behind the friends check means a store
        // created before MeRecord existed never gets one, and the profile shows a stranger
        // for the rest of that install.
        let identities = (try? context.fetch(FetchDescriptor<MeRecord>())) ?? []
        if identities.isEmpty {
            context.insert(
                MeRecord(
                    handle: "matthew",
                    bio: "Builds things, walks everywhere, always knows a coffee place.",
                    bannerTint: 0,
                    ageTier: AgeTier.adult.rawValue,
                    // Seeded as already onboarded, so -seedDemo lands on the map. Walking
                    // first run is what -resetOnboarding is for.
                    onboardedAt: .now
                )
            )
            try? context.save()
        }

        // Idempotent: relaunching with the flag must not double every friend.
        let existing = (try? context.fetch(FetchDescriptor<FriendRecord>())) ?? []
        guard existing.isEmpty else { return }

        let base = LocationService.fallback
        let day = 60.0 * 60 * 24

        let people: [(String, String, Int, Int, Int, Bool, String, [String])] = [
            ("sunny", "Seoul", 41, 12, 430, true,
             "Turns any 20-minute errand into a whole day out.",
             ["never on time", "knows a guy", "will drive anywhere"]),
            ("jae", "San Francisco", 14, 6, 210, false,
             "Orders for the table without asking and is always right.",
             ["encyclopedic about snacks", "loud laugher"]),
            ("mira", "Lisbon", 4, 3, 90, false,
             "Sends the photo three months later, perfectly timed.",
             ["takes the long way", "sends voice notes"]),
            ("toby", "San Francisco", 1, 1, 6, false,
             "", ["met once, at a bus stop"]),
        ]

        for (handle, city, meetups, places, daysAgo, top5, move, traits) in people {
            let friend = FriendRecord(
                handle: handle,
                metCity: city,
                metDate: .now.addingTimeInterval(-day * Double(daysAgo)),
                traits: traits,
                move: move,
                meetups: meetups,
                distinctPlaceCount: places,
                mutualTopFive: top5
            )
            context.insert(friend)
            context.insert(
                CatchRecord(
                    kind: meetups > 0 ? "snap" : "tag",
                    happenedAt: friend.metDate,
                    cell: GeoCell(latitude: base.latitude, longitude: base.longitude).id,
                    placeLabel: city,
                    friend: friend
                )
            )
        }

        // Memories scattered a few hundred metres out, so the map has something to place
        // and the distance maths is exercised rather than assumed.
        let pins: [(String, String, Double, Double, Int)] = [
            ("sunny", "Dolores Park",   0.0016, -0.0011, 1_100),
            ("jae",   "the ramen place", -0.0009,  0.0018, 260),
            ("mira",  "Ocean Beach",     0.0021,  0.0009, 640),
        ]
        for (handle, place, dLat, dLon, daysAgo) in pins {
            context.insert(
                MemoryRecord(
                    friendHandle: handle,
                    placeLabel: place,
                    happenedOn: .now.addingTimeInterval(-day * Double(daysAgo)),
                    latitude: base.latitude + dLat,
                    longitude: base.longitude + dLon
                )
            )
        }

        try? context.save()
    }
}
#endif
