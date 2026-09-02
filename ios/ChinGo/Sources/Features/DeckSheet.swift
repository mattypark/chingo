import SwiftUI
import ChinGoDesign

/// Everything you can do, in one place.
///
/// One entry point instead of a row of orbs across the bottom. The map is the product; every
/// control permanently parked on top of it is a piece of the world you cannot see.
///
/// Only actions that actually work appear here. A row that opens nothing, or says "coming
/// soon", teaches people that this menu is decorative — and a menu nobody trusts is worse
/// than a menu with three items in it.
struct DeckSheet: View {
    var onAlbum: () -> Void
    var onAddFriend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetShell("What now") {
        VStack(spacing: 0) {
            row(
                icon: "square.grid.2x2.fill",
                title: "Album",
                detail: "Everyone you have caught",
                action: onAlbum
            )
            row(
                icon: "person.badge.plus",
                title: "Add someone",
                detail: "They tell you their handle",
                action: onAddFriend
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.margin)
        }
    }

    private func row(
        icon: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Space.snug) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Ink.signal)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Ink.signal.opacity(0.12)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.chinHeadline)
                        .foregroundStyle(Ink.text)
                    Text(detail)
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.textSoft)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.textFaint)
            }
            .padding(Space.snug)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Ink.groundRaised)
                    .elevated(.low)
            )
        }
        .buttonStyle(SquashButtonStyle())
        .padding(.bottom, Space.tight)
    }
}
