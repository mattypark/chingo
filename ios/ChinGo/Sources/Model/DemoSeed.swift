#if DEBUG
import CoreLocation
import Foundation
import SwiftData
import ChinGoDesign
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

    /// `-onboardStep look` opens first run already on that screen.
    ///
    /// Sibling of `-open`, and there for the same reason: a screen four taps into a flow is a
    /// screen that stops getting looked at.
    /// `-accent 4` forces the seeded identity onto that accent.
    ///
    /// Eight accents times every screen is not something anyone will tap through by hand, so
    /// the screenshot pass gets a flag. Applied on every `-seedDemo` launch, not only the
    /// first, so the same install can be shot in each colour.
    static var accentOverride: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-accent"), args.index(after: i) < args.endIndex else {
            return nil
        }
        return Int(args[args.index(after: i)])
    }

    /// `-skyAltitude -5` pins the sun there instead of computing it.
    ///
    /// The whole twilight ramp happens in about twenty minutes a day. Without a way to force
    /// it, the interesting nine tenths of the sky palette is not something anyone will look
    /// at on purpose.
    static var skyAltitude: Double? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-skyAltitude"), args.index(after: i) < args.endIndex else {
            return nil
        }
        return Double(args[args.index(after: i)])
    }

    /// `-skyAzimuth 0` puts the sun straight ahead regardless of the real time of day.
    ///
    /// Sibling of `-skyAltitude`. Forcing the height without the direction leaves the sun
    /// wherever it genuinely is, which at most hours is behind you and off screen -- so the
    /// one thing the flag exists to show you is the one thing you cannot see.
    static var skyAzimuth: Double? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-skyAzimuth"), args.index(after: i) < args.endIndex else {
            return nil
        }
        return Double(args[args.index(after: i)])
    }

    static var onboardStep: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-onboardStep"), args.index(after: i) < args.endIndex else {
            return nil
        }
        return args[args.index(after: i)]
    }

    /// `-answer matthew` fills in the name, `-age 22` fills in the age.
    ///
    /// Two flags rather than one, because one flag typed itself into every question it
    /// reached: the name arrived on the age step as well, where a three-character limit
    /// truncated it to "mat" and the age gate refused a word.
    static func answer(for step: String) -> String? {
        let flag = step == "age" ? "-age" : "-answer"
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), args.index(after: i) < args.endIndex else {
            return nil
        }
        return args[args.index(after: i)]
    }

    /// `-streak lapsed|none` picks which streak the seeded history produces.
    ///
    /// The seeded friends were met 430, 210, 90 and 6 days ago, which is a realistic history
    /// and produces no day streak whatsoever -- so the one screen that exists to show a streak
    /// could only ever be looked at in its empty state. This adds a short run of recent
    /// meetups and lets it be moved:
    ///
    /// - default: a live streak, so the pill and the sheet have a number in them.
    /// - `lapsed`: the same run, pushed back so the last two days are missing. That is the
    ///   only state where the repair button exists, and it cannot be reached by waiting.
    /// - `none`: no recent meetups at all, which is a fresh install's real state.
    /// - `repaired`: `lapsed`, with the gap already frozen and one repair spent. Proves the
    ///   read path -- a stored freeze reaching the counter through the real store -- which
    ///   the button's own tap cannot be made to do from the command line.
    static var streak: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-streak"), args.index(after: i) < args.endIndex else {
            return nil
        }
        return args[args.index(after: i)]
    }

    /// A short run of recent meetups, so the streak is something that can be looked at.
    private static func seedStreak(
        into context: ModelContext,
        around base: CLLocationCoordinate2D,
        on handle: String
    ) {
        guard streak != "none" else { return }
        // `repaired` is `lapsed` with the repair already spent, so it shares the shift.

        let day = 60.0 * 60 * 24
        // Shifted back by two days in the lapsed case, which leaves yesterday and the day
        // before empty -- exactly the gap two repairs can bridge.
        let shift = (streak == "lapsed" || streak == "repaired") ? 2.0 : 0
        let descriptor = FetchDescriptor<FriendRecord>()
        guard let friend = (try? context.fetch(descriptor))?.first(where: { $0.handle == handle })
        else { return }

        for offset in 0..<3 {
            context.insert(
                CatchRecord(
                    kind: "snap",
                    happenedAt: .now.addingTimeInterval(-day * (Double(offset) + shift)),
                    cell: GeoCell(latitude: base.latitude, longitude: base.longitude).id,
                    placeLabel: friend.metCity,
                    friend: friend
                )
            )
        }

        guard streak == "repaired" else { return }
        let today = MapState.dayOrdinal(of: .now, in: Calendar(identifier: .iso8601))
        let identity = (try? context.fetch(FetchDescriptor<MeRecord>()))?.first
        // Yesterday is the only day the shift leaves uncovered: the run ends the day before.
        identity?.frozenDays = [today - 1]
        identity?.freezesLeft = MeRecord.freezeAllowance - 1
    }

    /// `-tour globe` opens the globe a beat after launch and leaves again a beat later.
    ///
    /// `-open globe` lands you inside it, which is the right flag for looking at the screen
    /// and the wrong one for looking at the way in: by the time anything is recorded the
    /// transition has already happened. A tour drives the door both ways so the staggered
    /// swap can actually be filmed, which is the only way to tell whether the pieces are
    /// ordered or merely all fading together.
    static var tour: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-tour"), args.index(after: i) < args.endIndex else {
            return nil
        }
        return args[args.index(after: i)]
    }

    /// `-autoSubmit` presses the question's own primary button a beat after it appears.
    ///
    /// Sibling of `-open`, and there for a stronger version of the same reason. `simctl` can
    /// launch straight onto a screen but it cannot tap anything on it, so a beat that only
    /// happens *on submit* -- the answer rising into the question's place -- is invisible from
    /// the command line. Without this the one animation the screen exists to get right is the
    /// one thing that ships on trust.
    static var autoSubmits: Bool {
        ProcessInfo.processInfo.arguments.contains("-autoSubmit")
    }

    /// Presence, which does not live in the store.
    ///
    /// `MapState.nearby` stays empty until the backend wires real presence, so without this
    /// the rail has nothing to draw and cannot be looked at. Same flag, same idempotence.
    /// `around` re-places them at wherever the map actually opened.
    ///
    /// Seeding against `LocationService.fallback` alone means the demo people sit in Dolores
    /// Park no matter where the simulator is pointed, so testing anywhere else shows an empty
    /// street. Called again once a real coordinate arrives.
    @MainActor
    static func populate(_ state: MapState, around: CLLocationCoordinate2D? = nil) {
        guard isRequested else { return }
        guard state.nearby.isEmpty || around != nil else { return }
        // Scattered around the fallback position at real metre offsets, each in a different
        // colour and half of them walking, so the bear layer exercises tinting, idle, walk
        // and depth sorting rather than five identical statues in a line.
        // Out, not hidden. Discovery is off by default in the real app and that is correct,
        // but a demo that opens hidden shows dashed grey rings and no bears -- which is the
        // state working exactly as designed and looking like nothing was built.
        state.discoverable = true

        let base = around ?? LocationService.fallback
        let people: [(String, Int, Double, Double, Int, Double?)] = [
            // Spread over roughly 25 to 90 metres, which at the zoom the map opens at puts
            // them between the player puck and the discovery ring. Tighter than this and they
            // all hide behind the puck; wider and they are outside the ring they are supposed
            // to be inside.
            ("priya",   40,  0.00022,  0.00018, 6, 145),
            ("sam",     80, -0.00034,  0.00026, 3, nil),
            ("marcus", 120,  0.00046, -0.00038, 4, 20),
            ("dana",   160, -0.00052, -0.00024, 1, nil),
            ("wren",   200,  0.00018,  0.00058, 5, 300),
        ]
        state.nearby = people.map { handle, metres, dLat, dLon, accent, course in
            NearbyPerson(
                id: "n-\(handle)",
                handle: handle,
                approxMetres: metres,
                coordinate: CLLocationCoordinate2D(
                    latitude: base.latitude + dLat,
                    longitude: base.longitude + dLon
                ),
                accent: accent,
                course: course
            )
        }
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
            // Switched on for the demo only. The real default is off, and the invitation
            // screen it produces is reachable with -globeOff -- a state worth being able to
            // screenshot, because for a fresh install it is the *normal* one.
            if let identity = (try? context.fetch(FetchDescriptor<MeRecord>()))?.first {
                identity.globeEnabled = !ProcessInfo.processInfo.arguments.contains("-globeOff")
            }
            try? context.save()
        }

        // After the identity exists, so a fresh install honours the flag on its first launch
        // rather than only on the second.
        if let forced = accentOverride {
            for record in (try? context.fetch(FetchDescriptor<MeRecord>())) ?? [] {
                record.bannerTint = forced
            }
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

        // Where each of them is on the globe, and whether both sides have said yes.
        //
        // Deliberately mixed: two who are visible, one who has only agreed in one direction,
        // and one with no position at all. That is the state the screen has to look right in
        // -- the version where everybody is sharing is the version that hides every bug in
        // the consent rule.
        let globe: [String: (lat: Double, lon: Double, hoursAgo: Double, mine: Bool, theirs: Bool, accent: Int)] = [
            "sunny": (37.5665, 126.9780, 0.4, true, true, 3),
            "mira": (38.7223, -9.1393, 2.5, true, true, 5),
            "jae": (37.7749, -122.4194, 1.0, true, false, 1),
            "toby": (0, 0, 0, false, false, 6),
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
            if let where_ = globe[handle] {
                friend.accentIndex = where_.accent
                friend.iShareWith = where_.mine
                friend.theyShareWithMe = where_.theirs
                if where_.mine || where_.theirs {
                    friend.globeLatitude = where_.lat
                    friend.globeLongitude = where_.lon
                    friend.globeUpdatedAt = .now.addingTimeInterval(-3600 * where_.hoursAgo)
                }
            }
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

        seedStreak(into: context, around: base, on: people.first.map { $0.0 } ?? "sunny")

        // Memories scattered a few hundred metres out, so the map has something to place
        // and the distance maths is exercised rather than assumed.
        let pins: [(String, String, Double, Double, Int)] = [
            // Deliberately inside the 150 m resurfacing radius and well past the twelve-hour
            // floor, so the memory nudge is something you can see on launch rather than
            // something you have to go for a walk to trigger. Every other pin is outside it.
            ("wren",  "the crosswalk",  0.0004,  0.0003, 9),
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

        // One caught last night and still developing, so the waiting state is something you
        // can look at now rather than tomorrow morning.
        context.insert(
            MemoryRecord(
                friendHandle: "toby",
                placeLabel: "the corner",
                happenedOn: .now.addingTimeInterval(-day * 0.4),
                latitude: base.latitude - 0.0008,
                longitude: base.longitude - 0.0014,
                developsAt: Develop.next(after: .now)
            )
        )

        try? context.save()
    }
}
#endif
