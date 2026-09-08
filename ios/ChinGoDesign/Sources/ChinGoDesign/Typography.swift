import SwiftUI

/// Bagel Fat One is the voice of the game; SF Pro is the voice of the app; Gloria
/// Hallelujah is the voice of a person.
///
/// Both bundled faces ship under the OFL. Nothing is fetched at runtime.
///
/// This is a deliberate divergence from Fitti, where Bagel appears exactly once. ChinGo
/// is a game — Bagel carries the numbers, the counts, the level, the catch button. But
/// it never carries a sentence. The moment a display face sets body copy, the app stops
/// looking playful and starts looking generated.
public enum Typeface {
    /// PostScript names, NOT filenames. `Font.custom` matches on the PostScript name and
    /// falls back to the system font **silently** when it misses — no warning, no crash,
    /// just the wrong typeface shipping unnoticed. Gloria's is "GloriaHallelujah" even
    /// though the file is GloriaHallelujah-Regular.ttf.
    public static let bagel = "BagelFatOne-Regular"
    public static let gloria = "GloriaHallelujah"
}

public extension Font {

    // MARK: Game voice — Bagel. Numbers and short shouts only.

    /// The wordmark.
    static let chinDisplay = Font.custom(Typeface.bagel, size: 40, relativeTo: .largeTitle)
    /// A level, a catch count, an XP number. The figures that want to feel like a score.
    static let chinNumeral = Font.custom(Typeface.bagel, size: 28, relativeTo: .title)
    /// What somebody just typed, on a screen that asks one question.
    ///
    /// Bigger than the wordmark on purpose. When the question is small and grey at the top and
    /// the answer is the largest thing on screen, the screen stops looking like a form and
    /// starts looking like a conversation -- the answer is the content, and the field is not
    /// there at all. Below about 40pt the effect collapses and it reads as a heading again.
    static let chinAnswer = Font.custom(Typeface.bagel, size: 46, relativeTo: .largeTitle)
    /// Button lids: CATCH, SNAP, RECONNECT. Two words at most.
    static let chinShout = Font.custom(Typeface.bagel, size: 17, relativeTo: .headline)

    // MARK: App voice — SF Pro. Everything a person actually reads.

    static let chinTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let chinHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let chinBody = Font.system(.body, design: .rounded, weight: .regular)
    static let chinCallout = Font.system(.subheadline, design: .rounded, weight: .medium)
    static let chinFootnote = Font.system(.footnote, design: .rounded, weight: .regular)
    /// Tracked-out uppercase metadata. Smallest text the app is allowed to set.
    static let chinLabel = Font.system(.caption, design: .rounded, weight: .semibold)

    // MARK: Human voice — Gloria. A friend talking, and one list of names.

    /// The move a friend wrote on your card. A memory's caption.
    ///
    /// Not a control label — with one amendment recorded in `DESIGN.md`: the nearby rail sets
    /// its names in Gloria, because a handwritten column of who is standing around you is the
    /// app naming people rather than an interface labelling a control. `NearbyRail` sets the
    /// face directly rather than taking this style, since its sizes ramp with focus.
    static let chinHand = Font.custom(Typeface.gloria, size: 16, relativeTo: .callout)
}

public extension View {
    /// The wordmark. Negative tracking because Bagel's sidebearings are drawn for a body
    /// face; at 40pt they read as gaps.
    func chinDisplayStyle() -> some View {
        font(.chinDisplay).tracking(-0.8)
    }

    /// Scores. Monospaced digits so a counter ticking 9 → 10 doesn't shove the layout.
    func chinNumeralStyle() -> some View {
        font(.chinNumeral).monospacedDigit().tracking(-0.4)
    }

    /// Uppercase metadata. The tracking is what makes 12pt read as a label rather than
    /// as small body text.
    func chinLabelStyle() -> some View {
        font(.chinLabel).textCase(.uppercase).tracking(0.9)
    }
}
