import SwiftUI

/// The one loud colour, and the fact that the player owns it.
///
/// `Ink` holds the colours that are true about the product -- the cream ground, the ink, the
/// jade counterweight, the mascot's berry. This holds the one colour that is true about the
/// *person*, picked once during onboarding and changeable afterwards. It lives apart from
/// `Ink` for exactly that reason: everything in `Ink` is a decision the app made, and this is
/// the only one it handed over.
///
/// Stored as an index, never as a hex. `MeRecord.bannerTint` keeps the number; a hex written
/// into a database outlives the rebrand that should have retired it.
///
/// **Why eight and not a colour wheel.** A wheel produces pale yellow on cream, and a label
/// nobody can read. Each entry here ships its own `onSignal`, measured rather than guessed,
/// and `AccentTests` fails the build if any of them drops under 4.5:1.
public struct Accent: Identifiable, Sendable, Equatable, Hashable {

    /// Index into `all`. This is what `MeRecord.bannerTint` stores.
    public let id: Int
    /// Shown next to the swatch. Lowercase, because the app speaks in lowercase.
    public let name: String

    /// The loud one: the catch button, the level ring, the focused name in the rail.
    public let signal: Color
    /// Pressed, and the deep half of anything that needs two steps of the same hue.
    public let signalDeep: Color
    /// What goes *on* `signal`. Ink for the light accents, cream for the dark ones -- which
    /// one is not a style preference, it is whichever clears 4.5:1, per accent.
    public let onSignal: Color
    /// The basemap tint. The same hue with most of the shout taken out, because the map is
    /// the largest surface in the product and a saturated accent across it would leave
    /// nothing for the accent to mean.
    public let mapWash: Color

    public init(
        id: Int,
        name: String,
        signal: Color,
        signalDeep: Color,
        onSignal: Color,
        mapWash: Color
    ) {
        self.id = id
        self.name = name
        self.signal = signal
        self.signalDeep = signalDeep
        self.onSignal = onSignal
        self.mapWash = mapWash
    }

    /// Eight hues, roughly evenly spaced, each measured against cream and ink before it was
    /// allowed in. Ordered warm-to-cool-to-warm so the swatch grid reads as a wheel rather
    /// than as a list.
    ///
    /// Index 0 is the colour the app shipped with. It stays first and it stays that exact
    /// hex, so nobody who never opens the picker sees their app change.
    public static let all: [Accent] = [
        Accent(
            id: 0, name: "coral",
            signal: Color(hex: 0xFF5A3C), signalDeep: Color(hex: 0xD93B20),
            onSignal: Ink.text, mapWash: Color(hex: 0xCB8B80)
        ),
        Accent(
            id: 1, name: "amber",
            signal: Color(hex: 0xE8890C), signalDeep: Color(hex: 0xAB6305),
            onSignal: Ink.text, mapWash: Color(hex: 0xB08750)
        ),
        Accent(
            id: 2, name: "moss",
            signal: Color(hex: 0x6B9E2E), signalDeep: Color(hex: 0x4D741F),
            onSignal: Ink.text, mapWash: Color(hex: 0x6D8452)
        ),
        Accent(
            id: 3, name: "pine",
            signal: Color(hex: 0x157A67), signalDeep: Color(hex: 0x0D5A4B),
            onSignal: Ink.onSignal, mapWash: Color(hex: 0x356159)
        ),
        Accent(
            id: 4, name: "cobalt",
            signal: Color(hex: 0x2B62D9), signalDeep: Color(hex: 0x1944A2),
            onSignal: Ink.onSignal, mapWash: Color(hex: 0x667CAB)
        ),
        Accent(
            id: 5, name: "violet",
            signal: Color(hex: 0x7A3FC4), signalDeep: Color(hex: 0x572991),
            onSignal: Ink.onSignal, mapWash: Color(hex: 0x856DA2)
        ),
        Accent(
            id: 6, name: "rose",
            signal: Color(hex: 0xC42057), signalDeep: Color(hex: 0x90143E),
            onSignal: Ink.onSignal, mapWash: Color(hex: 0x9C546C)
        ),
        Accent(
            id: 7, name: "clay",
            signal: Color(hex: 0x9A5230), signalDeep: Color(hex: 0x713A21),
            onSignal: Ink.onSignal, mapWash: Color(hex: 0x816253)
        ),
    ]

    /// The accent at `index`, clamped.
    ///
    /// Clamped rather than optional on purpose: this is read on every frame of every screen,
    /// from a number that came out of a database. A store written by a future build with nine
    /// accents, opened by this one, must render a map -- not a crash and not a blank.
    public static func at(_ index: Int) -> Accent {
        all[min(max(index, 0), all.count - 1)]
    }

    /// What a brand-new store gets before anyone has chosen.
    public static let fallback = all[0]
}

// MARK: - Environment

private struct AccentKey: EnvironmentKey {
    static let defaultValue = Accent.fallback
}

public extension EnvironmentValues {
    /// The player's accent.
    ///
    /// An environment value rather than a static on `Ink`, because a `static let` cannot
    /// change and cannot tell SwiftUI that it did. Every view that shows the accent reads it
    /// from here, so changing it in the profile repaints the app on the same frame.
    var accent: Accent {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }
}
