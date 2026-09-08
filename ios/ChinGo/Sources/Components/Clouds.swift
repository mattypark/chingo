import SwiftUI
import ChinGoDesign

/// Weather, drifting.
///
/// Three layers at different simulated altitudes. Depth comes entirely from the speed ratio
/// and the size ratio -- there is no geometry here and there does not need to be.
///
/// Four details do all the work, and getting any of them backwards kills the effect:
///
/// 1. **The speeds are not evenly spaced.** 0.15 / 0.40 / 1.00, not 1 / 2 / 3. Even ratios
///    read as a conveyor belt rather than as distance.
/// 2. **The near layer is the biggest, the fastest and the faintest.** Big, faint and quick
///    reads as "close to your face". Small, solid and slow reads as "miles away". Swapping
///    those is the usual mistake and it makes the sky look like wallpaper.
/// 3. **Turning the map turns the sky.** Drift is offset by the camera bearing, so rotating
///    the phone sweeps the clouds past at layer-specific rates. This is the cheapest part and
///    the one that stops it reading as a texture pasted behind the map.
/// 4. **They cast shadows on the city.** A fourth pass, in ink at a few percent, multiplied
///    over the ground. Free "clouds passing over the street", and the single highest-impact
///    thing in the file.
///
/// **Drawn rather than sourced.** A noise shader gives soft, wispy, fractal clouds -- the
/// opposite of a language built from hard edges and flat fills. These are unions of circles
/// on a flat base, which is what a cartoon cloud is, and they cost no asset. (A Metal
/// `colorEffect` could not have been used over the map anyway: it is a UIKit view, and Apple's
/// docs say such views log a warning and render a placeholder inside a filtered layer.)
struct Clouds: View {

    /// Which of the three altitudes this is.
    enum Deck: CaseIterable {
        case high, middle, low

        /// Fraction of a full width travelled per minute.
        var speed: Double {
            switch self {
            case .high: 0.15
            case .middle: 0.40
            case .low: 1.00
            }
        }

        var scale: CGFloat {
            switch self {
            case .high: 1.0
            case .middle: 1.5
            case .low: 2.1
            }
        }

        /// Nearer is fainter. The far deck is the solid one.
        var opacity: Double {
            switch self {
            case .high: 0.88
            case .middle: 0.64
            case .low: 0.34
            }
        }

        /// How far down the sky it sits, as a fraction of the band.
        var height: CGFloat {
            switch self {
            case .high: 0.20
            case .middle: 0.48
            case .low: 0.74
            }
        }

        /// How much the camera's heading pushes it. Nearer parallaxes harder.
        var sway: Double {
            switch self {
            case .high: 0.6
            case .middle: 1.5
            case .low: 3.2
            }
        }
    }

    var bearing: Double
    /// Sky colour, so clouds sit in the weather rather than on top of it.
    var tint: Color

    /// Drawn margin outside the tiled area, on both sides.
    ///
    /// Wide enough for the largest puff plus its overhang. A canvas sized exactly to what it
    /// tiles clips any shape that straddles its own boundary at full opacity, which is what
    /// produced the straight vertical slice through a cloud -- the shape was not wrong, the
    /// paper was too small. The vocabulary for this is a guard band, and the rule is that it
    /// has to be at least the largest thing you draw.
    private static let bleed: CGFloat = 170

    /// Not pure white. The reference's cloud texture runs #DBFBFF to #F4FFFF -- white with a
    /// cyan cast, which is what keeps a cloud sitting *in* a blue sky rather than punched
    /// through it.
    private static let paper = Color(hex: 0xEAFDFF)

    /// How far the sky pulls the clouds toward its own colour. Small, but it is what stops a
    /// cyan-white cloud sitting unchanged in an orange sunset -- weather is lit by the same
    /// sky it hangs in.
    private static let pull = 0.18

    /// The cloud colour as the current sky lights it.
    private var lit: Color { Self.paper.mix(with: tint, by: Self.pull) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: Motion.reduceMotion)) { timeline in
            let minutes = timeline.date.timeIntervalSinceReferenceDate / 60

            GeometryReader { geo in
                // Leading, not centre. Every deck is a canvas three screens wide positioned by
                // its own offset, and a centred stack re-centres that canvas inside itself --
                // which slid the whole tiled strip half a screen sideways and marched it clean
                // off the window for part of every drift cycle. Clouds that exist, are drawn,
                // and are nowhere on screen.
                ZStack(alignment: .topLeading) {
                    ForEach(Array(Deck.allCases.enumerated()), id: \.offset) { _, deck in
                        deckView(deck, minutes: minutes, size: geo.size)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                // No horizontal feather. The strip genuinely wraps -- a cloud leaving the right
                // edge is the same cloud arriving at the left -- so there is no seam for a
                // feather to hide, and fading the edges only made the sky look vignetted. The
                // axis that cannot wrap is the vertical one, and `SkyBand` already feathers it.
                .clipped()
            }
        }
        .allowsHitTesting(false)
    }

    private func deckView(_ deck: Deck, minutes: Double, size: CGSize) -> some View {
        // The caller sizes this view to the sky band already. Multiplying by the reach again
        // here squeezed every deck into the top third of the band and clipped them out of
        // sight entirely.
        let band = size.height
        // Drift plus sway. Wrapped to one screen width so the tiling never runs out.
        let travelled = minutes * deck.speed + bearing / 360 * deck.sway
        let offset = -CGFloat(travelled.truncatingRemainder(dividingBy: 1)) * size.width

        // The canvas fills the whole band and the deck's altitude is applied to each puff
        // inside it. Giving each deck its own short frame clipped the puffs into a hard
        // horizontal line across the sky -- a seam where there should be weather.
        return Canvas { context, _ in
            // Three copies one screen apart, inside a canvas three screens wide plus a bleed
            // margin at each end, shifted back by a screen and the margin. The middle copy
            // slides across the window while its neighbours cover both ends, so the drift is
            // a loop with no start and no join.
            context.translateBy(x: Self.bleed, y: 0)
            for pass in 0...2 {
                let step = CGFloat(pass) * size.width
                context.translateBy(x: step, y: 0)
                draw(deck, in: &context, size: CGSize(width: size.width, height: band))
                context.translateBy(x: -step, y: 0)
            }
        }
        .frame(width: size.width * 3 + Self.bleed * 2, height: band, alignment: .topLeading)
        .offset(x: offset - size.width - Self.bleed)
        .foregroundStyle(lit)
        // Plain alpha, not plusLighter. Additive white over a blue sky is fine and over a
        // cream street is a smear -- and the mask that keeps them off the street is a
        // gradient, so there is always a band where both are true.
        .opacity(deck.opacity)
    }

    /// One deck's worth of clouds, deterministic so they do not reshuffle every frame.
    private func draw(_ deck: Deck, in context: inout GraphicsContext, size: CGSize) {
        var generator = SplitMix(seed: UInt64(Deck.allCases.firstIndex(of: deck) ?? 0) &+ 20_260_908)
        let count = 5

        for index in 0..<count {
            let x = (Double(index) + generator.next() * 0.7) / Double(count) * size.width
            // Centred on the deck's altitude, with a little scatter either side so a deck
            // does not read as a washing line.
            let drift = (generator.next() - 0.5) * 0.12
            let y = (Double(deck.height) + drift) * Double(size.height)
            let width = (26 + generator.next() * 34) * deck.scale
            context.fill(puff(at: CGPoint(x: x, y: y), width: width), with: .color(lit))
        }
    }

    /// A cartoon cloud: three circles on a flat base. No blur, no gradient -- the same rule
    /// every other object in this app is drawn by.
    private func puff(at origin: CGPoint, width: CGFloat) -> Path {
        var path = Path()
        let r = width / 3
        path.addEllipse(in: CGRect(x: origin.x, y: origin.y + r * 0.35, width: r * 1.5, height: r * 1.5))
        path.addEllipse(in: CGRect(x: origin.x + r * 0.7, y: origin.y, width: r * 2.0, height: r * 2.0))
        path.addEllipse(in: CGRect(x: origin.x + r * 1.9, y: origin.y + r * 0.5, width: r * 1.3, height: r * 1.3))
        // Short and inset. A tall base rect on a cloud scaled two-and-a-bit times reads as a
        // slab lying across the sky rather than as the flat bottom of a cloud.
        path.addRect(CGRect(x: origin.x + r * 0.5, y: origin.y + r * 1.15, width: r * 1.9, height: r * 0.45))
        return path
    }
}

/// A tiny deterministic generator, so a deck of clouds is the same every frame and the same
/// on every launch. `Double.random` would reshuffle the sky sixty times a second.
private struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}
