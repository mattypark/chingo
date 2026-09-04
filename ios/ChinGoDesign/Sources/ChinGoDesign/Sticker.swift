import SwiftUI

/// The sticker language.
///
/// Derived from Bagel Fat One rather than from another app. The typeface has one idea —
/// extreme weight, fully rounded terminals, tight counters, and **no thin stroke anywhere** —
/// so the interface around it is built from the same rule:
///
/// - **Hard shadows, zero blur.** A blurred shadow says "floating pane". A hard offset says
///   "a thing printed and stuck down", which is what a fat rounded letterform looks like.
/// - **Thick outlines.** 3pt, in ink. A 1pt hairline next to a 40pt letterform is a different
///   design language sharing a screen.
/// - **Flat fills.** No gradients on components. Bagel has no gradient in it.
/// - **Press sinks into the shadow.** The block moves down-right by exactly its shadow offset
///   and the shadow disappears, so pressing looks like actually pressing something down
///   rather than dimming it.
///
/// It is also deliberately the opposite of the app it keeps being compared to: Pokémon GO's
/// chrome is glassy — translucent fills, hairline strokes, soft blur. Every one of those is
/// banned here. Same energy, none of the trade dress.
public struct Sticker: ViewModifier {
    private let fill: Color
    private let outline: Color
    private let radius: CGFloat
    private let pressed: Bool

    /// How far the shadow sits down and right. One value everywhere, because the whole thing
    /// reads as printed on one surface — varying it would imply pieces at different heights,
    /// which is a soft-shadow idea.
    public static let drop: CGFloat = 4

    public init(
        fill: Color,
        outline: Color = Ink.text,
        radius: CGFloat = Radius.card,
        pressed: Bool = false
    ) {
        self.fill = fill
        self.outline = outline
        self.radius = radius
        self.pressed = pressed
    }

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(outline, lineWidth: 3)
            }
            .compositingGroup()
            // radius: 0 is the whole point. SwiftUI's shadow blurs by default and a blurred
            // version of this reads as an ordinary card with a heavy border.
            .shadow(color: pressed ? .clear : outline, radius: 0, x: pressed ? 0 : Self.drop, y: pressed ? 0 : Self.drop)
            .offset(x: pressed ? Self.drop : 0, y: pressed ? Self.drop : 0)
    }
}

public extension View {
    func sticker(
        fill: Color,
        outline: Color = Ink.text,
        radius: CGFloat = Radius.card,
        pressed: Bool = false
    ) -> some View {
        modifier(Sticker(fill: fill, outline: outline, radius: radius, pressed: pressed))
    }
}

/// A button that behaves like a sticker: it sinks into its own shadow.
///
/// Replaces `SquashButtonStyle` on anything wearing the sticker treatment. Scaling a block
/// that has a hard offset shadow makes the shadow slide out from under it, which looks like
/// a bug; moving it into the shadow is the motion the shape is actually asking for.
public struct StickerButtonStyle: ButtonStyle {
    private let fill: Color
    private let outline: Color
    private let radius: CGFloat

    public init(fill: Color, outline: Color = Ink.text, radius: CGFloat = Radius.card) {
        self.fill = fill
        self.outline = outline
        self.radius = radius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sticker(
                fill: fill,
                outline: outline,
                radius: radius,
                pressed: configuration.isPressed
            )
            // Fast and flat. A spring here would make the block wobble after landing, and a
            // printed thing does not wobble.
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

/// A circular sticker — same rules, round.
public struct StickerCircleStyle: ButtonStyle {
    private let fill: Color
    private let outline: Color

    public init(fill: Color, outline: Color = Ink.text) {
        self.fill = fill
        self.outline = outline
    }

    public func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed

        return configuration.label
            .background {
                Circle().fill(fill)
            }
            .overlay {
                Circle().strokeBorder(outline, lineWidth: 3)
            }
            .compositingGroup()
            .shadow(
                color: down ? .clear : outline,
                radius: 0,
                x: down ? 0 : Sticker.drop,
                y: down ? 0 : Sticker.drop
            )
            .offset(x: down ? Sticker.drop : 0, y: down ? Sticker.drop : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}
