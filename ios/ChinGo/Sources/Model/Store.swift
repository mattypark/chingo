import Foundation
import SwiftData
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
    var friend: FriendRecord?

    init(
        id: String = UUID().uuidString,
        kind: String,
        happenedAt: Date = .now,
        cell: String,
        placeLabel: String? = nil,
        photoFile: String? = nil,
        friend: FriendRecord? = nil
    ) {
        self.id = id
        self.kind = kind
        self.happenedAt = happenedAt
        self.cell = cell
        self.placeLabel = placeLabel
        self.photoFile = photoFile
        self.friend = friend
    }
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
        lastSurfaced: Date? = nil
    ) {
        self.id = id
        self.friendHandle = friendHandle
        self.placeLabel = placeLabel
        self.happenedOn = happenedOn
        self.latitude = latitude
        self.longitude = longitude
        self.photoFile = photoFile
        self.lastSurfaced = lastSurfaced
    }

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
