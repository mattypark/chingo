import SwiftUI
import ChinGoDesign
import ChinGoEngine

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

    /// How far the camera is raked back. The haze starts wherever the horizon is.
    var pitch: Double

    /// Blend factor against `Ink.mapHaze`, keyed on how far *below the horizon* a point is,
    /// as a fraction of the ground still visible under it.
    ///
    /// Stated relative to the horizon rather than to the screen, because the horizon moves
    /// with pitch and these numbers were solved from a reference frame with its own. Keyed to
    /// absolute screen fractions they would only be correct at one camera angle -- which was
    /// the previous version's bug, in a file whose own comment says the ramp is
    /// pitch-specific.
    /// Scaled back from the measured curve, and the reason is geometry rather than taste.
    ///
    /// The reference numbers were solved from a frame whose camera showed far less ground per
    /// screen inch. Now that there is a real horizon the same alphas cover a much deeper strip
    /// of world, so the mid-distance -- where most of the street grid actually is -- went to
    /// pale wash and the roads disappeared. The shape of the falloff is what matters and it is
    /// unchanged; only the depth of it is down about a quarter.
    private static let ramp: [(depth: CGFloat, alpha: Double)] = [
        (0.000, 0.32),
        (0.040, 0.305),
        (0.092, 0.292),
        (0.181, 0.216),
        (0.257, 0.163),
        (0.346, 0.112),
        (0.422, 0.090),
        (0.500, 0.058),
        (0.665, 0.038),
        (0.831, 0.009),
        (1.000, 0.000),
    ]

    /// The ramp, mapped onto this camera's actual screen.
    private var stops: [Gradient.Stop] {
        let horizon = SkyBand.horizon(atPitch: pitch) ?? 0
        let ground = max(1 - horizon, 0.01)
        return [.init(color: Ink.mapHaze.opacity(0), location: 0)]
            + Self.ramp.map {
                .init(
                    color: Ink.mapHaze.opacity($0.alpha),
                    location: min(horizon + $0.depth * ground, 1)
                )
            }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                stops: stops,
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
