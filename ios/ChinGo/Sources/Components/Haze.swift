import SwiftUI
import ChinGoDesign

/// Distance, on a map that has none.
///
/// The ground is one flat green and it reads as felt, which is the last thing left over from
/// taking the buildings out. Pokemon GO's ground is not flat either -- it runs `#A4EFAC` under
/// your feet to `#6BE8CC` at the horizon -- and the mechanism is Unity linear fog, which every
/// surface in the scene is blended toward as it recedes. That is why their roads get *lighter*
/// with distance while their ground gets *darker*: both are converging on one colour, and the
/// colour they converge on is the sky's own bottom edge. There is no horizon line in that game
/// because at the horizon everything is already the same colour.
///
/// MapLibre Native has no fog and no sky -- both are open issues, not oversights on our part --
/// so it cannot be done in the style. It does not need to be. **At a fixed camera pitch, screen
/// Y is a monotonic function of depth**, so a vertical gradient over the map computes the same
/// quantity in a different parameterisation. This is not an approximation of fog; it is fog,
/// solved for y instead of for z.
///
/// The alpha ramp is measured rather than eyeballed. Sampling the road in a Pokemon GO
/// screenshot at nine depths and solving each sample against the horizon colour gives the
/// blend factor directly, and it is emphatically not linear -- it falls off fast in the first
/// tenth of the screen below the horizon and then trails. A linear ramp here looks like a
/// tinted window; this looks like air.
///
/// **The one thing that invalidates it: pitch.** The mapping from depth to y is a function of
/// camera pitch, so if the map is ever raked to a different angle these stops have to be
/// re-measured. That is the price of solving it in screen space, and it is worth paying
/// because the alternative is not available on this renderer.
struct Haze: View {

    /// Blend factor against `Ink.mapHaze`, keyed on fraction of screen height.
    ///
    /// Starts at the horizon rather than at the top of the screen -- above the horizon is
    /// `SkyBand`'s problem, and doubling the two would double-tint the strip where they meet.
    private static let ramp: [(location: CGFloat, alpha: Double)] = [
        (SkyBand.horizon, 0.42),
        (0.270, 0.400),
        (0.310, 0.386),
        (0.378, 0.287),
        (0.436, 0.219),
        (0.504, 0.151),
        (0.562, 0.122),
        (0.621, 0.080),
        (0.747, 0.054),
        (0.873, 0.012),
        (1.000, 0.000),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [.init(color: Ink.mapHaze.opacity(0), location: 0)]
                    + Self.ramp.map { .init(color: Ink.mapHaze.opacity($0.alpha), location: $0.location) },
                startPoint: .top,
                endPoint: .bottom
            )

            heroLight
        }
        .allowsHitTesting(false)
    }

    /// A soft brightening around where you are standing.
    ///
    /// Also measured, and much smaller than the haze -- about four lightness points across the
    /// width of the screen. Small enough that nobody will ever name it, large enough that
    /// without it the middle of the map is the same value as the edges and the whole frame
    /// sits flat. It is the difference between a lit scene and a printed one.
    private var heroLight: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [.white.opacity(0.05), .white.opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.55),
                startRadius: 0,
                endRadius: geo.size.width * 0.45
            )
            .blendMode(.plusLighter)
        }
    }
}
