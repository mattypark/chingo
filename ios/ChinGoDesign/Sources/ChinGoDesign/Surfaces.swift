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

    public init(radius: CGFloat = 26, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    public var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Ink.groundRaised)
                    .shadow(color: Ink.shade, radius: 18, x: 0, y: 8)
                    .shadow(color: Ink.shadeSoft, radius: 3, x: 0, y: 1)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Capsule(style: .continuous)
                    .fill(Ink.groundRaised)
                    .shadow(color: Ink.shade, radius: 10, x: 0, y: 4)
            }
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
                        .shadow(color: Ink.shade, radius: 12, x: 0, y: 5)
                }
        }
        .buttonStyle(SquashButtonStyle())
        // 54pt clears the 44pt minimum with room for gloves and thumbs in motion —
        // this app is used while walking.
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
