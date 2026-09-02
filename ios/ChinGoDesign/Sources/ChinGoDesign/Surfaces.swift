import SwiftUI

/// The chrome that floats over the map.
///
/// Pokémon GO's screen architecture is the reference and it is worth being precise about
/// why it works: the map owns the whole screen, and every control is a small, rounded,
/// clearly-detached object sitting *above* it. Nothing is docked to an edge in a bar.
/// That is what makes the world feel like the app rather than the background of the app.
///
/// So every control in ChinGo is one of these three surfaces, and none of them are square,
/// full-width, or flush to an edge.

/// A floating rounded slab: trays, sheets, the card back, anything with content in it.
public struct FloatingSurface<Content: View>: View {
    private let radius: CGFloat
    private let content: Content

    public init(radius: CGFloat = Radius.surface, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    public var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Ink.groundRaised)
                    .elevated(.card)
                    // A second, tight shadow directly under the edge. One shadow gives a
                    // surface height; the contact shadow is what stops it looking pasted on.
                    .elevated(.low)
            }
    }
}

/// A small floating capsule: counts, status, the streak, a place name.
public struct FloatingPill<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, Space.snug)
            .padding(.vertical, Space.tight)
            .background {
                Capsule(style: .continuous)
                    .fill(Ink.groundRaised)
                    .elevated(.float)
            }
            .frame(minHeight: Space.minimumHitTarget)
    }
}

/// A round floating button. The map screen's whole control vocabulary is circles.
public struct FloatingOrb<Content: View>: View {
    private let diameter: CGFloat
    private let tint: Color
    private let action: () -> Void
    private let content: Content

    public init(
        diameter: CGFloat = 54,
        tint: Color = Ink.groundRaised,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.diameter = diameter
        self.tint = tint
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button(action: action) {
            content
                .frame(width: diameter, height: diameter)
                .background {
                    Circle()
                        .fill(tint)
                        .elevated(.float)
                }
        }
        .buttonStyle(SquashButtonStyle())
        // 54pt clears the 44pt minimum with room for thumbs in motion — this app is used
        // while walking, where the target is moving relative to the hand.
        .hitTarget()
        .accessibilityAddTraits(.isButton)
    }
}

/// Press physics for every button in the app. Scale plus a touch of dimming, on the tap
/// spring — so a control that is pressed feels pressed rather than merely re-coloured.
public struct SquashButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
