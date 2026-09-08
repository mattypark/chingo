import SwiftUI

/// Things arrive by being drawn, and leave by being un-drawn.
///
/// The sticker language says every object on screen is a thing printed and stuck down. Until
/// now it appeared by fading or scaling, which is how a *photograph* of a printed thing
/// arrives — the object was always finished and the screen simply revealed it. Drawing it is
/// the honest version: a line, then an outline, then the colour inside it, then what is
/// written on it, in the order a hand would do it.
///
/// It reverses exactly, which is the other half of why it is worth having. A screen leaves by
/// the words going, the colour draining, the outline retracting the way it came, and the line
/// pulling back to where it started — a crayon drawing run backwards. Nothing else in the app
/// can leave that way, because nothing else was built.
///
/// **Four beats, and they overlap.** Strictly sequential beats read as four separate events
/// waiting for each other; each one starts a little before the one in front of it has
/// finished, which is what makes it one gesture. The ranges are open for testing rather than
/// private, because the ordering is the entire design and it is invisible in a still.
public struct Drawn: Equatable, Sendable {

    /// How far through the whole gesture, 0 to 1.
    public let progress: Double

    public init(_ progress: Double) {
        self.progress = min(max(progress, 0), 1)
    }

    /// Nothing drawn yet.
    public static let blank = Drawn(0)
    /// Finished, and indistinguishable from a plain sticker.
    public static let complete = Drawn(1)

    // MARK: The beats
    //
    // Each is a window on the overall progress, mapped back to its own 0…1.

    /// The stem, or whatever line ties the object to the thing it belongs to. Goes first,
    /// because it is the gesture of reaching toward the thing before drawing it.
    public var line: Double { Self.eased(progress, from: 0.00, to: 0.22) }

    /// The border, stroked on around the shape. The longest beat: it is the one that reads as
    /// drawing, and rushing it turns the whole thing into a flash.
    public var outline: Double { Self.eased(progress, from: 0.14, to: 0.62) }

    /// The colour flooding the shape, from the bottom up like paint settling into it.
    public var fill: Double { Self.eased(progress, from: 0.48, to: 0.82) }

    /// What is written on it. Last, and quick — text that draws itself is a different effect
    /// and a much cheaper-looking one.
    public var content: Double { Self.eased(progress, from: 0.74, to: 1.00) }

    /// Whether anything is drawn at all. Callers use it to skip work entirely while blank.
    public var isBlank: Bool { progress <= 0 }

    /// A window of the overall progress, remapped to 0…1 and smoothed at both ends.
    ///
    /// Smoothstep rather than linear: a stroke that begins and ends at full speed reads as a
    /// wipe revealing a finished line, and the thing that makes it read as *drawing* is that
    /// the hand accelerates away and slows into the corner.
    static func eased(_ progress: Double, from start: Double, to end: Double) -> Double {
        guard end > start else { return progress >= end ? 1 : 0 }
        let t = min(max((progress - start) / (end - start), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// A sticker that draws itself on.
///
/// Same result as `.sticker(fill:radius:)` at `.complete` — the same 3pt outline, flat fill and
/// hard zero-blur shadow — so a view can be built once and animated or not without looking
/// like two different objects.
///
/// **`Animatable`, and that is load-bearing rather than tidy.** Without it SwiftUI interpolates
/// each leaf it can see — the opacity, the trim, the mask's scale — independently, from its
/// blank value to its finished one, over the same duration. Every beat then runs at once and
/// the whole thing collapses into a fade with extra steps. Declaring `progress` as the
/// animatable data means SwiftUI interpolates *that*, and `body` re-derives the four beats on
/// every frame, which is the only way the ordering survives contact with the animator.
public struct DrawnSticker: ViewModifier, Animatable {
    private let fill: Color
    private let outline: Color
    private let radius: CGFloat
    private var drawn: Drawn

    /// `nonisolated` because `Animatable` is not main-actor isolated and `View`/`ViewModifier`
    /// are, so a plain conformance straddles the two and Swift 6 refuses it.
    public nonisolated var animatableData: Double {
        get { drawn.progress }
        set { drawn = Drawn(newValue) }
    }

    public init(
        fill: Color,
        outline: Color = Ink.text,
        radius: CGFloat = Radius.card,
        drawn: Drawn
    ) {
        self.fill = fill
        self.outline = outline
        self.radius = radius
        self.drawn = drawn
    }

    public func body(content: Content) -> some View {
        content
            // The content keeps its space from the first frame, so the outline is drawn around
            // the size the finished thing will be rather than growing to meet it. A box that
            // draws itself at one size and then resizes is two animations fighting.
            .opacity(drawn.content)
            .background {
                shape
                    .fill(fill)
                    // Paint settling into the shape rather than the whole thing fading up.
                    // A mask anchored to the bottom means the fill has a direction, and a
                    // direction is what separates filling from appearing.
                    .mask(alignment: .bottom) {
                        Rectangle().scaleEffect(y: drawn.fill, anchor: .bottom)
                    }
            }
            .overlay {
                shape
                    // `.trim` is the whole trick: a `RoundedRectangle` is a `Shape`, so its
                    // border can be drawn as a fraction of its own perimeter.
                    .trim(from: 0, to: drawn.outline)
                    .stroke(outline, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .compositingGroup()
            // The shadow arrives with the fill. A hard offset shadow under an outline that is
            // still being drawn reads as a second, wrong-shaped object behind the first.
            .shadow(
                color: outline.opacity(drawn.fill),
                radius: 0,
                x: Sticker.drop * drawn.fill,
                y: Sticker.drop * drawn.fill
            )
    }

    private var shape: some InsettableShape {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

public extension View {
    /// Draw this on, in four beats. See `Drawn`.
    func drawnSticker(
        fill: Color,
        outline: Color = Ink.text,
        radius: CGFloat = Radius.card,
        drawn: Drawn
    ) -> some View {
        modifier(DrawnSticker(fill: fill, outline: outline, radius: radius, drawn: drawn))
    }
}

/// The line that reaches toward the thing a card belongs to, drawn from its far end back.
///
/// A separate shape rather than a `Rectangle` with an animated height, because it has to grow
/// *away* from the card — a frame that animates its height grows from wherever its alignment
/// puts it, and getting that to read as reaching down took more guessing than drawing the line
/// outright does.
public struct DrawnStem: View, Animatable {
    private let length: CGFloat
    private var drawn: Drawn
    private let colour: Color

    /// Same reason as `DrawnSticker`: the stem has to be driven by the shared progress, or it
    /// draws itself over the whole gesture instead of leading it.
    public nonisolated var animatableData: Double {
        get { drawn.progress }
        set { drawn = Drawn(newValue) }
    }

    public init(length: CGFloat, drawn: Drawn, colour: Color = Ink.text) {
        self.length = length
        self.drawn = drawn
        self.colour = colour
    }

    public var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 1.5, y: 0))
            path.addLine(to: CGPoint(x: 1.5, y: length))
        }
        .trim(from: 0, to: drawn.line)
        .stroke(colour, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .frame(width: 3, height: length)
    }
}
