import SwiftUI

/// Every colour in the app resolves through here. One file to swap when the mascot
/// lands and the brand hue is fixed.
///
/// The map is the largest surface in the product, so its colours are defined here too
/// and exported to the MapLibre style JSON — the basemap and the chrome cannot be
/// allowed to drift apart into two different-looking products.
public enum Ink {

    // MARK: Ground

    /// White paper. This was warm cream, on the reasoning that white chrome floating over a
    /// white map has no edge — which was true of the placeholder map and stopped being true
    /// the day the basemap went green. Matthew's call, and the map is what makes it safe: a
    /// white card on a green field separates on its own, and every card also carries a 3pt ink
    /// outline and a hard shadow, so the edge was never the ground's job in the first place.
    public static let ground = Color(hex: 0xFFFFFF)
    /// Raised surfaces are the same white. In this language a raised block is told apart by
    /// its outline and the hard offset under it, not by being a shade lighter than the sheet —
    /// two near-identical whites separated by a hairline of tone is the soft-elevation idea
    /// the sticker treatment replaced.
    public static let groundRaised = Color(hex: 0xFFFFFF)
    /// A well: the one ground that still steps *down*, because a hole cannot be told from its
    /// surface by an outline it does not have. Neutral now rather than warm, so it reads as
    /// shadow on white paper rather than as the last piece of cream left behind.
    public static let groundSunk = Color(hex: 0xEDEDED)

    // MARK: Text

    public static let text = Color(hex: 0x1C1A16)
    public static let textSoft = Color(hex: 0x6B655A)
    public static let textFaint = Color(hex: 0xA39C8D)
    public static let onSignal = Color(hex: 0xFFFFFF)

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
    // Green ground, one road colour, one casing colour, no buildings. This is a deliberate
    // break from the warm paper the rest of the app is made of, and the reason is that the map
    // is not paper -- it is the ground you are standing on, and the chrome floating over it is
    // the paper. Cream cards on a green field separate cleanly; cream cards on a cream field
    // needed a shadow to exist at all.
    //
    // These are not invented. They are sampled off Pokemon GO's own shipped assets and
    // full-resolution screenshots: the ramp textures the game indexes by distance
    // (`GroundRamp.png`, `RoadRamp.png`, `RoadOutlineRamp.png`, `WaterGrad.png`) and pixel
    // measurements of the near field, where the distance fog has not yet taken hold. Working
    // from the near field matters -- the far field is already half sky, and matching *that*
    // is what `Haze` does instead.
    //
    // Two of them are the ones that are easy to get wrong:
    //
    // - **The road is not neutral grey.** It is a desaturated teal, the same hue family as the
    //   ground, 35 points darker and 40 less saturated. A true grey road on green reads as
    //   pasted on; this one reads as part of the same world.
    // - **The casing is yellow, and every road class gets it,** down to parking aisles. It is
    //   the single loudest thing in the palette and it is what makes a road network read as
    //   one connected object rather than as a classification. Hierarchy is carried by width
    //   alone -- no class has its own hue.
    //
    // Exported to worker/style/chingo.json, and corrected on the way in by `MapStyle` while
    // the generator still emits the old palette.

    /// The ground. Everything that is not water, park or road.
    public static let mapLand = Color(hex: 0xA4EFAC)
    /// Land parcels -- residential, commercial, school, industrial. A few lightness points
    /// off the ground and nothing more.
    ///
    /// This is the texture that replaces buildings. With the extrusions gone, the ground is
    /// the largest flat area in the product by a wide margin, and a single uniform green reads
    /// as felt. Parcel boundaries put low-frequency variation back into it without adding
    /// anything you have to look at. Keep the hue within about eight degrees of `mapLand` --
    /// past that the blocks start reading as a classification rather than as texture.
    public static let mapLandParcel = Color(hex: 0x9CEEA9)
    /// Parks and grass. A 40-point lightness step down from the ground rather than a nudge:
    /// on a field that is already green, a park five percent darker reads as a rendering
    /// artefact rather than as a park.
    public static let mapPark = Color(hex: 0x3FA878)
    /// Protected land and nature reserves -- darker again, so the two do not merge.
    public static let mapParkDeep = Color(hex: 0x2E9668)
    public static let mapWater = Color(hex: 0x25A0DB)
    /// The carriageway, every class.
    public static let mapRoad = Color(hex: 0x4E8E81)
    /// The edge of the ribbon, every class.
    public static let mapRoadCasing = Color(hex: 0xF6F49F)
    /// Footpaths. Pale, solid and uncased -- the one part of the network drawn as a different
    /// thing rather than as a narrower road.
    public static let mapPath = Color(hex: 0xEAF4F4)

    // MARK: Flat map
    //
    // A second, quieter palette for the globe screen, where the map is a backdrop for people
    // rather than a board you play on.
    //
    // The street map shouts on purpose: saturated green, dark ribbons, yellow edges, roads at
    // two and a half times their cartographic width. All of that exists so the ground reads as
    // a game surface at walking scale. Pull back to a city and the same choices become noise —
    // there is nothing to play on at that zoom, only somewhere to find a face.
    //
    // So this one gets out of the way. Near-white paper, white roads with the faintest warm
    // edge, pale water, and parks a suggestion rather than a statement. Everything saturated
    // on this screen is a person.

    public static let flatLand = Color(hex: 0xF2EFE9)
    /// Blocks and parcels, barely a shade off the ground -- enough that a city reads as having
    /// texture, not enough to be a classification.
    public static let flatParcel = Color(hex: 0xEDE9E1)
    public static let flatPark = Color(hex: 0xDCE8CD)
    public static let flatParkDeep = Color(hex: 0xCFE0BC)
    public static let flatWater = Color(hex: 0xBEE0F0)
    /// White, and that is the whole trick. On a near-white ground the road network reads as a
    /// negative space rather than as drawn lines -- which is why this kind of map looks calm
    /// even when a city is dense.
    public static let flatRoad = Color(hex: 0xFFFFFF)
    /// A warm grey a hair darker than the paper. Present enough to give a road an edge,
    /// quiet enough that a junction is not a diagram.
    public static let flatRoadCasing = Color(hex: 0xE4DFD6)
    public static let flatPath = Color(hex: 0xF7F5F1)

    /// The haze the ground fades into at the horizon. Effectively white with a cyan cast, and
    /// the same colour the sky bottoms out at, which is the whole trick -- see `Haze`.
    public static let mapHaze = Color(hex: 0xD0F9FF)

    // Buildings are no longer drawn -- `MapStyle.removeBuildings` strips the layers. These
    // stay because the generated style still contains the colours and the correction table
    // still has to name something to map them to.
    public static let mapBuilding = Color(hex: 0x9CEEA9)
    public static let mapBuildingWarm = Color(hex: 0xACEDB5)
    public static let mapBuildingSide = Color(hex: 0x93E9A6)

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
