import SwiftUI

/// The frame every sheet in ChinGo sits in.
///
/// The reason it exists is the close control. iOS sheets dismiss by dragging down, which is
/// invisible: people who know the gesture never think about it, and people who don't get
/// stuck holding a panel they cannot put away. So every sheet gets a circular ✕ pinned below
/// its content — the position Pokémon GO uses, and for the same reason. A control you can see
/// beats a gesture you have to already know.
///
/// Swipe-to-dismiss stays. Removing it would fight the OS, and the point is to add a second
/// way out, not to take one away.
public struct SheetShell<Content: View>: View {
    private let title: String?
    private let content: Content

    @Environment(\.dismiss) private var dismiss

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let title {
                Text(title)
                    .font(.chinTitle)
                    .foregroundStyle(Ink.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.margin)
                    .padding(.top, Space.margin)
                    .padding(.bottom, Space.snug)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CloseButton { dismiss() }
                .padding(.top, Space.snug)
                .padding(.bottom, Space.inset)
        }
        .background(Ink.ground)
    }
}

/// The circular ✕.
///
/// Wears the sticker treatment like everything else, so the way out of a screen belongs to
/// the same object language as the things on it. It stays ground-coloured rather than signal
/// — it is the way out, not the thing to do, and a persimmon close button on a sheet whose
/// primary action is already persimmon reads as a choice between equals.
public struct CloseButton: View {

    /// What it is sitting on, which decides which way round it is drawn.
    public enum Ground {
        /// A cream sheet. The button is cream with an ink mark, like every other object here.
        case sheet
        /// A full-bleed colour field. Inverted, because a cream disc on a colour field is a
        /// hole punched in it -- the same reason the menu rows are ink.
        case field
    }

    private let ground: Ground
    private let action: () -> Void

    public init(on ground: Ground = .sheet, action: @escaping () -> Void) {
        self.ground = ground
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ground == .sheet ? Ink.text : Ink.onSignal)
                .frame(width: 50, height: 50)
        }
        .buttonStyle(
            ground == .sheet
                ? StickerCircleStyle(fill: Ink.groundRaised)
                : StickerCircleStyle(fill: Ink.text, outline: Ink.text)
        )
        .hitTarget()
        .accessibilityLabel("Close")
    }
}
