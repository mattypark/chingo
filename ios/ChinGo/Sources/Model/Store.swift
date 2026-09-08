import Foundation
import SwiftData
import ChinGoDesign
import ChinGoEngine

/// Local-first storage.
///
/// Everything works with no account and no network: catches, friends and memories are real
/// on the device the moment they happen. Supabase syncs them later, which means a dropped
/// connection in the middle of meeting someone costs nothing — the catch already happened,
/// the photo is already saved.
///
/// It also means the whole app is drivable in the simulator with no backend running.

@Model
final class FriendRecord {
    #Index<FriendRecord>([\.handle])
    @Attribute(.unique) var id: String
    var handle: String
    var metCity: String
    var metDate: Date
    var traits: [String]
    /// Written by you, about them. The other half — what they wrote about you — lives on
    /// their device until sync exists.
    var move: String
    var portraitFile: String?

    // MARK: Globe
    //
    // Two grants, stored separately, both defaulting to false so an existing friend picks up
    // the feature switched off rather than switched on. `ChinGoEngine.GlobeSharing` owns what
    // they mean; these only record what was agreed.

    /// They may see where you are.
    var iShareWith: Bool = false
    /// You may see where they are.
    var theyShareWithMe: Bool = false

    /// Their last known position, as the backend last sent it. Nil until it does.
    ///
    /// Held as three loose optionals rather than a struct because SwiftData migrates added
    /// optional properties without a schema version, and this has to land on installs that
    /// already exist.
    var globeLatitude: Double?
    var globeLongitude: Double?
    var globeUpdatedAt: Date?

    /// Which bear to draw for them on the globe. Their accent, by index.
    var accentIndex: Int = 0

    /// Denormalised bond counters. The tier itself is never stored: it is derived by
    /// `ChinGoEngine.Bond`, so the ladder can be retuned without a migration and can never
    /// drift out of sync with the numbers it came from.
    var meetups: Int
    var distinctPlaceCount: Int
    var mutualTopFive: Bool

    @Relationship(deleteRule: .cascade, inverse: \CatchRecord.friend)
    var catches: [CatchRecord] = []

    init(
        id: String = UUID().uuidString,
        handle: String,
        metCity: String,
        metDate: Date = .now,
        traits: [String] = [],
        move: String = "",
        portraitFile: String? = nil,
        meetups: Int = 0,
        distinctPlaceCount: Int = 0,
        mutualTopFive: Bool = false
    ) {
        self.id = id
        self.handle = handle
        self.metCity = metCity
        self.metDate = metDate
        self.traits = traits
        self.move = move
        self.portraitFile = portraitFile
        self.meetups = meetups
        self.distinctPlaceCount = distinctPlaceCount
        self.mutualTopFive = mutualTopFive
    }

    var history: BondHistory {
        BondHistory(
            meetups: meetups,
            distinctPlaces: distinctPlaceCount,
            daysKnown: Calendar.current.dateComponents([.day], from: metDate, to: .now).day ?? 0,
            mutualTopFive: mutualTopFive
        )
    }

    var tier: BondTier { Bond.tier(for: history) }
}

@Model
final class CatchRecord {
    @Attribute(.unique) var id: String
    /// "snap" or "tag". A string rather than an enum so a future kind does not require a
    /// store migration.
    var kind: String
    var happenedAt: Date
    /// The coarse cell, which is all that is ever sent anywhere.
    var cell: String
    var placeLabel: String?
    var photoFile: String?
    /// When the photo becomes visible. Nil means it already is.
    ///
    /// Optional rather than defaulted so that every photo taken before this rule existed
    /// stays visible. A migration that retroactively hid people's memories would be a bug
    /// wearing a feature's clothes.
    var developsAt: Date?
    var friend: FriendRecord?

    init(
        id: String = UUID().uuidString,
        kind: String,
        happenedAt: Date = .now,
        cell: String,
        placeLabel: String? = nil,
        photoFile: String? = nil,
        developsAt: Date? = nil,
        friend: FriendRecord? = nil
    ) {
        self.id = id
        self.kind = kind
        self.happenedAt = happenedAt
        self.cell = cell
        self.placeLabel = placeLabel
        self.photoFile = photoFile
        self.developsAt = developsAt
        self.friend = friend
    }

    var isDeveloped: Bool { Develop.isDeveloped(developsAt) }
}

/// You.
///
/// Its own record rather than a pile of UserDefaults keys, because this is the thing that
/// syncs to a server first when accounts land, and because a profile is content — it belongs
/// in the store with everything else the person has made.
@Model
final class MeRecord {
    @Attribute(.unique) var id: String
    var handle: String
    /// One line: what you're into, what you do. Deliberately short — a profile people
    /// actually fill in is one that fits in a sentence.
    var bio: String
    /// Which of the banner tints they picked, by index. Not a stored colour: colours belong
    /// to the palette, and a hex saved in a database survives a rebrand it should not.
    var bannerTint: Int

    /// The result of the age check, not the birthday that produced it.
    ///
    /// ChinGo never shows an age, sorts by one, or wishes anyone a happy birthday, so keeping
    /// the date would be holding personal data with no feature behind it. The date is
    /// evaluated once at the gate and discarded.
    /// Whether the morning alert is wanted. On by default, because it is the only
    /// notification the app sends and it is the payoff of something the player already did --
    /// but it is off in one tap, and turning it off silences the in-app version too. Toggles
    /// that only govern push while the app is closed are the reason people say notification
    /// settings do nothing.
    var wantsDevelopAlerts: Bool = true

    /// Whether walking past an old memory is allowed to mention it.
    ///
    /// A default value rather than an optional, which is what makes this a lightweight
    /// migration -- an existing install picks it up without a schema version.
    ///
    /// Separate from `wantsDevelopAlerts` because they are different promises. That one is a
    /// push, arriving on a phone in a pocket; this one only ever happens with the app open and
    /// in your hand, so it needs no permission and costs no battery. Folding them into one
    /// switch would mean somebody who declined push also silently lost a feature that never
    /// involved push.
    var wantsMemoryNudges: Bool = true

    // MARK: Globe
    //
    // Both default to the safe answer. `globeEnabled` false means a person who never opens
    // the feature is not in it, and `sharingPaused` exists so leaving is one tap that does
    // not require revoking anybody -- see `GlobeSharing`, where pausing is deliberately
    // indistinguishable from a flat battery.

    var globeEnabled: Bool = false
    var sharingPaused: Bool = false

    /// A face, if you want one. Optional in every sense: the type, the product decision, and
    /// the migration.
    ///
    /// The bear is the identity on the map and stays the identity on the map -- a portrait is
    /// a face on a card, not a body on a street, and swapping the avatar for a photograph
    /// would put a stranger's face at eye level in public, which is the shape of thing App
    /// Review guideline 1.2 exists for. So this shows where a face belongs and nowhere else.
    var portraitFile: String?
    var ageTier: Int

    /// When onboarding was completed. Nil means it has not been.
    var onboardedAt: Date?

    // MARK: The things that cannot be derived
    //
    // `MapState` rebuilds XP and both streaks from the `CatchRecord` list every time it
    // changes, which is why neither can drift. The four below have no record behind them --
    // nothing in the store says a freeze was spent, or that a memory was revisited -- so they
    // are stored, and `recompute` is handed them rather than accumulating anything itself.
    //
    // All defaulted, per the migration rule above: an install that already exists picks them
    // up without a schema version.

    /// XP earned by things that are not catches. Revisiting a memory is the only source today.
    ///
    /// Kept apart from the catch total rather than folded into one stored number, so a deleted
    /// catch still correctly un-earns what it earned.
    var awardedXP: Int = 0

    /// Repairs left. Finch ships two, and finite is the whole mechanic: a repair you can
    /// always afford is an undo, and an undo is not a decision.
    var freezesLeft: Int = MeRecord.freezeAllowance

    /// Day ordinals a freeze has been spent on. See `MapState.dayOrdinal(of:in:)`.
    ///
    /// A list rather than a count, because which days were covered is what the streak walk
    /// needs -- a bare number cannot tell it where the holes were.
    var frozenDays: [Int] = []

    /// The alternate icon chosen in the profile, or nil for the one the app ships with.
    var alternateIcon: String?

    /// Whether the bear is allowed to change the icon on its own after a long absence.
    ///
    /// Off by default and it has to stay that way. `setAlternateIconName` always shows a
    /// system alert that no public API can suppress, so an automatic swap fires "You have
    /// changed the icon for ChinGo" at somebody who is in another app entirely. Duolingo does
    /// exactly this and it is the part of their guilt mechanics people screenshot. Opt-in, and
    /// worded as something the bear does rather than something done to you.
    var wantsLapseIcon: Bool = false

    /// The last day the app was opened, as a day ordinal. Zero means never.
    ///
    /// Only the opt-in lapse icon reads this. It is deliberately not used to compute the
    /// streak: opening the app is not what the streak counts, and wiring this into it would
    /// turn the thing into exactly the leash `Streak`'s comment warns about.
    var lastActiveDay: Int = 0

    /// How many repairs somebody starts with, and the most a single repair may bridge.
    ///
    /// One constant for both, because they are the same fact from two directions: a gap you
    /// could not cover even by spending everything is a gap there is no point offering to fix.
    static let freezeAllowance = 2

    init(
        id: String = "me",
        handle: String = "",
        bio: String = "",
        bannerTint: Int = 0,
        ageTier: Int = 0,
        onboardedAt: Date? = nil
    ) {
        self.id = id
        self.handle = handle
        self.bio = bio
        self.bannerTint = bannerTint
        self.ageTier = ageTier
        self.onboardedAt = onboardedAt
    }

    var hasOnboarded: Bool { onboardedAt != nil }
}

@Model
final class MemoryRecord {
    @Attribute(.unique) var id: String
    var friendHandle: String
    var placeLabel: String
    var happenedOn: Date
    /// A memory keeps a precise point, because walking past it is the entire feature. It
    /// never leaves this device in that form.
    var latitude: Double
    var longitude: Double
    var photoFile: String?
    /// When the photo becomes visible. Nil means it already is. Kept here as well as on the
    /// catch because the map draws from memories, and a pin that showed the photo while the
    /// album still hid it would make the rule look like a bug in one of the two places.
    var developsAt: Date?
    /// Set the first time it resurfaces, so the app can avoid handing you the same memory
    /// every time you walk down the same street.
    var lastSurfaced: Date?

    init(
        id: String = UUID().uuidString,
        friendHandle: String,
        placeLabel: String,
        happenedOn: Date,
        latitude: Double,
        longitude: Double,
        photoFile: String? = nil,
        developsAt: Date? = nil,
        lastSurfaced: Date? = nil
    ) {
        self.id = id
        self.friendHandle = friendHandle
        self.placeLabel = placeLabel
        self.happenedOn = happenedOn
        self.latitude = latitude
        self.longitude = longitude
        self.photoFile = photoFile
        self.developsAt = developsAt
        self.lastSurfaced = lastSurfaced
    }

    var isDeveloped: Bool { Develop.isDeveloped(developsAt) }

    var cell: GeoCell { GeoCell(latitude: latitude, longitude: longitude) }

    var agoDescription: String {
        let years = Calendar.current.dateComponents([.year], from: happenedOn, to: .now).year ?? 0
        if years >= 1 { return "\(years) year\(years == 1 ? "" : "s") ago" }
        let months = Calendar.current.dateComponents([.month], from: happenedOn, to: .now).month ?? 0
        return months <= 1 ? "last month" : "\(months) months ago"
    }

    /// Memories within reach of a position, nearest first.
    ///
    /// Filtering happens in memory rather than in a predicate: SwiftData cannot express a
    /// haversine, and a personal camera roll's worth of pins is a few thousand rows at
    /// most, which is nothing to scan.
    static func near(
        latitude: Double,
        longitude: Double,
        in all: [MemoryRecord],
        radius: Double = Geo.memoryRadiusMetres
    ) -> [MemoryRecord] {
        all
            .map { ($0, Geo.metres(from: (latitude, longitude), to: ($0.latitude, $0.longitude))) }
            .filter { $0.1 <= radius }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}
