import Foundation

/// What a card shows. Deliberately shallow: the design package must be renderable in a
/// preview with no network, no database and no auth.
public struct CardFace: Identifiable, Sendable, Equatable {
    public let id: String
    public let handle: String
    /// Where the two of you first met, not where they live. The card is a record of a
    /// shared history, not a profile.
    public let metCity: String
    public let metDate: Date
    /// Self-chosen, editable, and personality rather than stats.
    public let traits: [String]
    /// Written by the friend who caught you. This is the only text on the card its owner
    /// did not write, and it is the reason the card is worth having.
    public let move: String
    public let moveAuthor: String
    public let tier: Int
    public let placesShared: Int
    public let catches: Int
    /// Local or remote image name for the pixel portrait. Nil renders the placeholder.
    public let portrait: String?

    public init(
        id: String,
        handle: String,
        metCity: String,
        metDate: Date,
        traits: [String],
        move: String,
        moveAuthor: String,
        tier: Int,
        placesShared: Int,
        catches: Int,
        portrait: String? = nil
    ) {
        self.id = id
        self.handle = handle
        self.metCity = metCity
        self.metDate = metDate
        self.traits = traits
        self.move = move
        self.moveAuthor = moveAuthor
        self.tier = tier
        self.placesShared = placesShared
        self.catches = catches
        self.portrait = portrait
    }
}
