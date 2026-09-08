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
    //
    // The one loud colour is not here. It is the one colour the player owns, so it lives in
    // `Accent` and arrives through `@Environment(\.accent)` — a `static let` cannot change
    // and cannot tell SwiftUI that it did. `Accent.all[0]` is the coral this file used to
    // hold, unchanged, so an install that never opens the picker looks exactly as it did.

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
    // Green ground, dark road ribbons, no buildings. This is a deliberate break from the warm
    // paper the rest of the app is made of, and the reason is that the map is not paper --
    // it is the ground you are standing on, and the chrome floating over it is the paper.
    // Cream cards on a green field separate cleanly; cream cards on a cream field needed a
    // shadow to exist at all.
    //
    // Exported to worker/style/chingo.json, and corrected on the way in by `MapStyle` while
    // the generator still emits the old palette.

    /// The ground. Everything that is not water, park or road.
    public static let mapLand = Color(hex: 0x6FCB79)
    /// Parks and grass -- a deeper green, so a park still reads as a park against ground that
    /// is already green rather than disappearing into it.
    public static let mapPark = Color(hex: 0x4FB162)
    public static let mapWater = Color(hex: 0x56C2DC)
    /// The carriageway. Dark and desaturated: on a green field the road is the one thing that
    /// has to stay legible while walking, and a light road on light green does not.
    public static let mapRoad = Color(hex: 0x4E6157)
    /// The edge of the ribbon. Darker than the fill rather than lighter, so a road reads as a
    /// solid object laid on the grass instead of an outline drawn on it.
    public static let mapRoadCasing = Color(hex: 0x39493F)

    // Buildings are no longer drawn -- `MapStyle.removeBuildings` strips the layers. These
    // stay because the generated style still contains the colours and the correction table
    // still has to name something to map them to.
    public static let mapBuilding = Color(hex: 0x64C070)
    public static let mapBuildingWarm = Color(hex: 0x5CB868)
    public static let mapBuildingSide = Color(hex: 0x4AA458)

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
