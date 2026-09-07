import SwiftUI

/// What a menu opens onto.
///
/// Not a dim over the map. When a menu takes the screen it takes it properly, so the moment
/// reads as stepping inside the app rather than as a panel laid on top of it. The map is
/// still there when you close it; it does not need to be watched while you choose.
///
/// **It is the player's colour, not the mascot's.** This was a berry field, on the argument
/// that a full-screen takeover should be unmistakably the bear's. That argument loses to a
/// simpler one: the accent is the only colour in the app the player chose, and the biggest
/// surface it could possibly appear on was showing somebody else's purple instead. Berry is
/// still the mascot's, and still on his own face and banner.
///
/// The gradient runs deep at the top to light at the bottom, which puts the lightest ground
/// under the controls, where the contrast is needed.
public struct MenuBackdrop: View {
    @Environment(\.accent) private var accent

    private let onTap: () -> Void

    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    public var body: some View {
        LinearGradient(
            colors: [accent.signalDeep, accent.signal, accent.signalLift],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        // Tapping the ground closes. Every takeover needs a way out that is not the one
        // control someone might not have looked for.
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// A label on a takeover menu.
///
/// Plain type on the berry field, no chip behind it. A capsule under every label turns a menu
/// into a list of buttons wearing buttons, and the field is already dark enough to carry
/// light text without help.
public struct MenuLabel: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            // Bagel, not tracked-out caps. The caps version was borrowed from the app this
            // one keeps getting compared to; the heavy face is ours and it is the reason the
            // rest of the sticker language exists.
            .font(.custom(Typeface.bagel, size: 13))
            .foregroundStyle(Ink.onSignal.opacity(0.88))
    }
}
