import SwiftUI

/// A person, as a card.
///
/// The reference the whole product came from is a Pokémon TCG card, so it is worth saying
/// exactly what is different and why. The TCG frame — colour type-banner, HP with a circle
/// glyph in the corner, a row of energy cost pips, a tan artwork window, and the
/// weakness/resistance/retreat strip along the bottom — is recognisable trade dress and is
/// not available to us.
///
/// What replaces it is better for this product anyway:
///   - Where HP would sit: the city the two of you met in. A number nobody earned versus
///     a fact only the two of you share.
///   - Where the type banner would sit: nothing. The tier is carried by the frame itself,
///     so the card gets quieter as it gets rarer instead of louder.
///   - Where the attack rows would sit: one move, written by the friend who caught you.
///   - Where the retreat strip would sit: the history — met, places, catches.
public struct CardView: View {
    @Environment(\.accent) private var accent

    private let face: CardFace
    private let width: CGFloat

    public init(face: CardFace, width: CGFloat = 300) {
        self.face = face
        self.width = width
    }

    private var scale: CGFloat { width / 300 }
    private var tierColour: Color {
        switch face.tier {
        case 3: Ink.tierRide
        case 2: Ink.tierCrew
        case 1: Ink.tierRegular
        default: Ink.tierMet
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            portrait
            traits
            move
            Spacer(minLength: 0)
            footer
        }
        .padding(14 * scale)
        .frame(width: width, height: width * 1.4)
        .background {
            RoundedRectangle(cornerRadius: 26 * scale, style: .continuous)
                .fill(Ink.groundRaised)
        }
        .overlay {
            // The tier lives in the frame. Met is a hairline; Ride-or-die is the only
            // gradient in the entire app, which is what makes it feel earned.
            RoundedRectangle(cornerRadius: 26 * scale, style: .continuous)
                .strokeBorder(frameStyle, lineWidth: (face.tier == 3 ? 4 : 2.5) * scale)
        }
        .shadow(color: Ink.shade, radius: 20 * scale, y: 10 * scale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(face.handle), met in \(face.metCity)")
    }

    private var frameStyle: AnyShapeStyle {
        face.tier == 3
            ? AnyShapeStyle(
                AngularGradient(
                    colors: [Ink.tierRide, accent.signal, Ink.tierRide, Ink.jade, Ink.tierRide],
                    center: .center
                )
              )
            : AnyShapeStyle(tierColour.opacity(face.tier == 0 ? 0.35 : 0.9))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(face.handle)
                .font(.custom(Typeface.bagel, size: 22 * scale))
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            Text(face.metCity)
                .chinLabelStyle()
                .foregroundStyle(Ink.textSoft)
                .lineLimit(1)
        }
        .padding(.bottom, 10 * scale)
    }

    private var portrait: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .fill(Ink.groundSunk)
            if let name = face.portrait {
                Image(name)
                    .resizable()
                    .interpolation(.none)          // pixel art must never be smoothed
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 46 * scale))
                    .foregroundStyle(Ink.textFaint)
            }
        }
        .frame(height: width * 0.72)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
    }

    private var traits: some View {
        // Three at most. A fourth turns a personality into a résumé.
        HStack(spacing: 6 * scale) {
            ForEach(face.traits.prefix(3), id: \.self) { trait in
                Text(trait)
                    .font(.system(size: 9.5 * scale, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Ink.textSoft)
                    .padding(.horizontal, 7 * scale)
                    .padding(.vertical, 4 * scale)
                    .background(Capsule().fill(Ink.groundSunk))
                    .lineLimit(1)
            }
        }
        .padding(.top, 10 * scale)
    }

    private var move: some View {
        VStack(alignment: .leading, spacing: 2 * scale) {
            Text(face.move)
                .font(.custom(Typeface.gloria, size: 14 * scale))
                .foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(face.moveAuthor)")
                .font(.system(size: 9.5 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(Ink.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10 * scale)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            stat("\(face.placesShared)", "places")
            Divider().frame(height: 20 * scale)
            stat("\(face.catches)", "catches")
            Divider().frame(height: 20 * scale)
            stat(face.metDate.formatted(.dateTime.month(.abbreviated).year()), "met")
        }
        .padding(.top, 10 * scale)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.custom(Typeface.bagel, size: 13 * scale))
                .foregroundStyle(Ink.text)
            Text(label)
                .font(.system(size: 8.5 * scale, weight: .medium, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Ink.textFaint)
        }
        .frame(maxWidth: .infinity)
    }
}

public extension CardFace {
    /// Preview data. Real enough to judge the design against.
    static let sample = CardFace(
        id: "sample",
        handle: "sunny",
        metCity: "Seoul",
        metDate: .now.addingTimeInterval(-60 * 60 * 24 * 400),
        traits: ["never on time", "will drive anywhere", "knows a guy"],
        move: "Turns any 20-minute errand into a whole day out.",
        moveAuthor: "matthew",
        tier: 3,
        placesShared: 12,
        catches: 41
    )
}
