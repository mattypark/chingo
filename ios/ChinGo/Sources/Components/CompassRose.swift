import SwiftUI
import ChinGoDesign

/// Which way is north, and a way back to walking.
///
/// The needle was already here as a bare arrow. What it was missing is the letter: an arrow on
/// a rotating map tells you *a* direction and leaves you to work out which one, and the whole
/// reason it exists is that the map has turned away from north. `N` at the point costs one
/// glyph and turns a hint into an answer.
///
/// The letter counter-rotates. It rides the needle around the dial so it always marks true
/// north, but it stays upright so it stays readable -- a rotating `N` reads as a `Z` twice per
/// turn, which is the one thing a compass may never do.
struct CompassRose: View {
    @Environment(\.accent) private var accent

    /// Map bearing in degrees. North sits at minus this.
    var bearing: Double
    var action: () -> Void

    private static let size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            ZStack {
                needle
                    .rotationEffect(.degrees(-bearing))
            }
            .frame(width: Self.size, height: Self.size)
        }
        .buttonStyle(StickerCircleStyle(fill: Ink.groundRaised))
        .hitTarget()
        .accessibilityLabel("Face the way you are walking")
        .accessibilityValue(heading)
    }

    private var needle: some View {
        VStack(spacing: 0) {
            Text("N")
                .font(.custom(Typeface.bagel, size: 9))
                .foregroundStyle(accent.signal)
                // Upright wherever the needle points.
                .rotationEffect(.degrees(bearing))
                .frame(height: 10)

            Image(systemName: "location.north.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent.signal)
        }
        .offset(y: -2)
    }

    /// Spoken as a compass point rather than a number. "Three hundred and twelve degrees" is
    /// not something anybody navigates by.
    private var heading: String {
        let points = ["north", "north-east", "east", "south-east",
                      "south", "south-west", "west", "north-west"]
        let normalised = (bearing.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return "facing \(points[Int((normalised / 45).rounded()) % 8])"
    }
}
