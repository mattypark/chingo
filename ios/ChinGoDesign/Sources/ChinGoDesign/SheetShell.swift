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
/// Bordered rather than filled: it is the way out, not the thing to do. A solid button here
/// competes with whatever the sheet is actually for, and on a sheet whose primary action is
/// already a filled capsule, two filled controls read as a choice between equals.
public struct CloseButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Ink.textSoft)
                .frame(width: 46, height: 46)
                .background {
                    Circle()
                        .fill(Ink.groundRaised)
                        .elevated(.low)
                }
                .overlay {
                    Circle().strokeBorder(Ink.groundSunk, lineWidth: 2)
                }
        }
        .buttonStyle(SquashButtonStyle())
        .hitTarget()
        .accessibilityLabel("Close")
    }
}
