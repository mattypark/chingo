import SwiftUI

/// Spacing, radius and elevation, as closed sets.
///
/// The reason this file exists at all: every AI-built interface converges on the same look,
/// and the mechanism is always the same — one spacing value used everywhere, one corner
/// radius on everything, one shadow under every surface. The result reads as generated
/// because nothing in it is a decision.
///
/// So these are enums with no initialiser. A view cannot invent `padding(13)` or
/// `cornerRadius(19)`; it picks from a set that was decided once. That constraint is the
/// entire point — it is not a convenience wrapper over numbers.

/// 8pt grid with 4pt subdivisions.
///
/// The values carry meaning, not just size: things that belong together sit at `tight`,
/// things that merely coexist sit at `section`. Uniform spacing is what makes a screen read
/// as a list of components rather than as a designed thing.
public enum Space {
    /// Between a glyph and its label. Parts of one object.
    public static let hair: CGFloat = 4
    /// Between tightly related fields — a value and its caption.
    public static let tight: CGFloat = 8
    /// Inside a control.
    public static let snug: CGFloat = 12
    /// The default gap between sibling elements.
    public static let step: CGFloat = 16
    /// Inside a card or sheet, from edge to content.
    public static let inset: CGFloat = 20
    /// Screen margin.
    public static let margin: CGFloat = 24
    /// Between unrelated sections. The jump that says "new subject".
    public static let section: CGFloat = 32

    /// Smallest tappable square Apple has ever accepted. Non-negotiable and checked, not
    /// eyeballed — on a map app used while walking, an undersized target is a missed tap in
    /// motion, not a nitpick.
    public static let minimumHitTarget: CGFloat = 44
}

/// Three radius tiers, tied to how large the thing is.
///
/// A 40pt chip and a 400pt sheet cannot share a corner radius — at the same value, one looks
/// square and the other looks like a pill. Radius tracks size or it tracks nothing.
public enum Radius {
    /// Chips, small controls, inline wells.
    public static let control: CGFloat = 12
    /// Cards, photo wells, list rows.
    public static let card: CGFloat = 20
    /// Sheets, the floating slabs over the map.
    public static let surface: CGFloat = 28

    /// Capsules stay capsules. Named so the intent is explicit at the call site rather than
    /// implied by a large number.
    public static let pill: CGFloat = .infinity
}

/// Shadow recipes by elevation.
///
/// Not one shadow reused. A pill resting just above the map, a card, and a sheet covering
/// half the screen are at genuinely different heights, and a single shadow flattens all three
/// into the same plane. Each tier scales blur and offset together, because a shadow whose
/// blur grows without its offset reads as a glow.
public struct Elevation: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat

    /// Resting on the surface below — a chip, a small pill.
    public static let low = Elevation(color: Ink.shadeSoft, radius: 6, y: 2)
    /// Floating clearly above the map — orbs, pills, the nearby tray.
    public static let float = Elevation(color: Ink.shade, radius: 12, y: 5)
    /// A card the user is meant to read as an object they could pick up.
    public static let card = Elevation(color: Ink.shade, radius: 18, y: 8)
    /// A sheet over everything else.
    public static let sheet = Elevation(color: Ink.shade, radius: 28, y: 14)
}

public extension View {
    /// Apply an elevation. One call, so a shadow can never be half-specified.
    func elevated(_ level: Elevation) -> some View {
        shadow(color: level.color, radius: level.radius, x: 0, y: level.y)
    }

    /// Guarantee the 44pt minimum without changing how the control looks.
    ///
    /// `contentShape` matters here: expanding the frame alone grows the layout but not the
    /// tappable region, which is the quiet version of this bug.
    func hitTarget() -> some View {
        frame(minWidth: Space.minimumHitTarget, minHeight: Space.minimumHitTarget)
            .contentShape(Rectangle())
    }
}
