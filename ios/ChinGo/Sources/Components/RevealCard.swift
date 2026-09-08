import SwiftUI
import ChinGoDesign

/// Who this is, once they are close enough to do something about.
///
/// Rises over a bear when they cross inside the interaction ring. It is the only thing on the
/// map that is a real view rather than a map symbol, because it has buttons on it.
///
/// **No banner, no sound, one haptic on the way in.** This fires whenever anybody walks past,
/// which on a busy street is often. Geocaching handles the same problem by sending nothing at
/// all at close range -- "your phone will vibrate when you are within 32 feet" -- and that
/// restraint is the right model for a signal this frequent.
struct RevealCard: View {
    @Environment(\.accent) private var accent

    /// Fixed, so the caller can keep the card clear of the right-hand rail without having to
    /// guess how wide a handle is. A card that resizes with the name would slide under the
    /// rail for anyone called something long and stay clear for everyone else.
    static let width: CGFloat = 196

    let person: NearbyPerson
    /// How far the bear sits from the middle of the card, once the card has been nudged away
    /// from the screen edge. The stem follows the bear; the card does not.
    var stemOffset: CGFloat = 0
    var onAdd: () -> Void
    var onCatch: () -> Void

    var body: some View {
        VStack(spacing: Space.tight) {
            HStack(spacing: Space.tight) {
                face
                Text(person.handle)
                    .font(.custom(Typeface.bagel, size: 19))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: Space.tight) {
                action("Add", filled: false, action: onAdd)
                action("Photo", filled: true, action: onCatch)
            }
        }
        .frame(width: Self.width - Space.snug * 2)
        .padding(Space.snug)
        .sticker(fill: Ink.groundRaised, radius: Radius.card)
        // The stem ties the card to the bear rather than leaving it hovering over the street
        // -- the same job the polaroid pins' stems already do.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Ink.text)
                .frame(width: 3, height: Self.stem)
                // Clamped inside the rounded corners. A stem leaving from the very edge of a
                // 20pt radius leaves from thin air.
                .offset(x: min(max(stemOffset, -Self.width / 2 + 20), Self.width / 2 - 20), y: Self.stem)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(person.handle) is close by")
    }

    /// How far the stem hangs below the card.
    static let stem: CGFloat = 14

    /// Their picture if they set one, otherwise their bear. The bear is the default identity,
    /// so a missing picture is the common case rather than a broken one.
    private var face: some View {
        Group {
            if let image = PhotoStore.load(person.portraitFile) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image("Mascot").resizable().scaledToFit().padding(2)
            }
        }
        .frame(width: 34, height: 34)
        .background(Circle().fill(Accent.at(person.accent).signal))
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Ink.text, lineWidth: 3))
    }

    private func action(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom(Typeface.bagel, size: 14))
                .foregroundStyle(filled ? accent.onSignal : Ink.text)
                .padding(.horizontal, Space.snug)
                .padding(.vertical, Space.hair + 2)
        }
        .buttonStyle(
            StickerButtonStyle(fill: filled ? accent.signal : Ink.ground, radius: Radius.control)
        )
        .hitTarget()
    }
}
