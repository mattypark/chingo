import SwiftUI

/// The chrome that floats over the map.
///
/// This file used to hold three surfaces built on soft, blurred elevation, and a note
/// explaining that nothing in ChinGo is ever docked to an edge in a bar. Both have since
/// been overruled by looking at the thing:
///
/// - The map's chrome was the last place still speaking the soft-shadow language while every
///   sheet and card had moved to `Sticker`. Two languages on one screen reads worse than
///   either of them does alone.
/// - Three controls pinned to three corners with the width of the screen between them did not
///   read as a set. `HomeBar` docks them, and the screen got calmer rather than heavier.
///
/// What is left is the pill -- restyled as a sticker -- and the press behaviour.

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
                Capsule(style: .continuous).fill(Ink.groundRaised)
            }
            .overlay {
                Capsule(style: .continuous).strokeBorder(Ink.text, lineWidth: 3)
            }
            .compositingGroup()
            .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)
            .frame(minHeight: Space.minimumHitTarget)
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
