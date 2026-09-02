import SwiftUI

/// Every colour in the app resolves through here. One file to swap when the mascot
/// lands and the brand hue is fixed.
///
/// The map is the largest surface in the product, so its colours are defined here too
/// and exported to the MapLibre style JSON — the basemap and the chrome cannot be
/// allowed to drift apart into two different-looking products.
public enum Ink {

    // MARK: Ground

    /// Warm paper, not white. White chrome floating over a white map has no edge.
    public static let ground = Color(hex: 0xF6F2E7)
    public static let groundRaised = Color(hex: 0xFFFDF7)
    public static let groundSunk = Color(hex: 0xEAE4D4)

    // MARK: Text

    public static let text = Color(hex: 0x1C1A16)
    public static let textSoft = Color(hex: 0x6B655A)
    public static let textFaint = Color(hex: 0xA39C8D)
    public static let onSignal = Color(hex: 0xFFFDF7)

    // MARK: Signal

    /// The one loud colour: the catch button, the level ring, anything that means "act".
    /// Deliberately warm — the whole category is Niantic blue and Snap yellow.
    public static let signal = Color(hex: 0xFF5A3C)
    public static let signalDeep = Color(hex: 0xD93B20)

    /// The calm counterweight. Water on the map, secondary chips, "you're safe" states.
    public static let jade = Color(hex: 0x2FB8A0)
    public static let jadeDeep = Color(hex: 0x1E8C78)

    // MARK: Berry
    //
    // The mascot's own colours, pulled out so a menu that takes over the screen is
    // unmistakably his. Used for full-screen takeovers and nothing else — a berry field
    // behind ordinary content would fight every card in the app.

    public static let berry = Color(hex: 0x7A2E52)
    public static let berryDeep = Color(hex: 0x431A31)
    public static let berryLift = Color(hex: 0x9C3F63)

    // MARK: Bond tiers
    //
    // Tiers are earned, never bought, so their colours climb in weight rather than in
    // noise: ink, then a metal, then a brighter metal, then the only gradient in the app.

    public static let tierMet = Color(hex: 0x8A8377)
    public static let tierRegular = Color(hex: 0xB0764A)
    public static let tierCrew = Color(hex: 0x9AA3AE)
    public static let tierRide = Color(hex: 0xE8B23A)

    // MARK: Map
    //
    // Exported to worker/style/chingo.json. Flat fills, no gradients: a basemap with
    // texture fights the cards that sit on top of it.

    public static let mapLand = Color(hex: 0xEDE7D6)
    public static let mapPark = Color(hex: 0xCFE0BC)
    public static let mapWater = Color(hex: 0xA8D8D0)
    public static let mapRoad = Color(hex: 0xFFFDF7)
    public static let mapRoadCasing = Color(hex: 0xDDD5C2)
    public static let mapBuilding = Color(hex: 0xE4DCC8)
    /// A minority of blocks, so a neighbourhood is not one flat tone.
    public static let mapBuildingWarm = Color(hex: 0xDCCFB4)
    /// The extruded side face. Buildings are drawn as a top over a darker side; without
    /// this the map is a diagram rather than a place.
    public static let mapBuildingSide = Color(hex: 0xC6B99C)

    // MARK: Depth
    //
    // One shadow recipe, used everywhere. Chrome floats above a map, so it needs a real
    // shadow — but a warm, low-opacity one, or the app reads as a dashboard.

    public static let shade = Color(hex: 0x3B3223).opacity(0.16)
    public static let shadeSoft = Color(hex: 0x3B3223).opacity(0.08)
}

public extension Color {
    /// `Color(hex: 0xFF5A3C)` — because six-digit hex is how the palette is discussed
    /// and `Color(red:green:blue:)` with three decimals is not.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
