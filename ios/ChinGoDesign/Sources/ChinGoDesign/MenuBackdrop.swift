import SwiftUI

/// What a menu opens onto.
///
/// Not a dim over the map. When a menu takes the screen it takes it properly — a deep berry
/// field in the mascot's own colours, so the moment reads as stepping inside the app rather
/// than as a panel laid on top of it. The map is still there when you close it; it does not
/// need to be watched while you choose.
///
/// The gradient runs dark at the top to light at the bottom, which puts the lightest ground
/// under the controls, where the contrast is needed.
public struct MenuBackdrop: View {
    private let onTap: () -> Void

    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    public var body: some View {
        LinearGradient(
            colors: [Ink.berryDeep, Ink.berry, Ink.berryLift],
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
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .textCase(.uppercase)
            .tracking(1.1)
            // Not full white. At full strength the labels compete with the icons they
            // describe; held back a little they read as captions, which is what they are.
            .foregroundStyle(Ink.onSignal.opacity(0.72))
    }
}
