import SwiftUI
import ChinGoDesign

/// Placeholder basemap.
///
/// Stage 4 replaces this with MapLibre Native rendering Protomaps PMTiles out of R2, using
/// these same colours from `Ink`. It exists now so the chrome that floats above the map can
/// be designed against a surface of the right value and temperature — floating controls
/// designed over a white rectangle disappear the moment a real map arrives underneath them.
///
/// Two things here are not decoration and must survive into the real map:
///
/// 1. **Perspective.** A map drawn flat reads as a document. A map raked back reads as a
///    world you are standing in. This is the single largest contributor to the screen
///    feeling like a game rather than a utility.
/// 2. **Irregularity.** A perfectly even grid reads as a quilt. Real cities have blocks of
///    different sizes, a few streets wider than the rest, and green and water that ignore
///    the grid entirely.
struct MapSurface: View {
    var tilt: Double = 58
    var heading: Double = -14

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 2.6
            let h = geo.size.height * 2.6

            ZStack {
                Ink.mapLand

                Canvas { context, size in
                    City.draw(in: &context, size: size)
                }
                .frame(width: w, height: h)
                .rotationEffect(.degrees(heading))
                .rotation3DEffect(
                    .degrees(tilt),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .center,
                    perspective: 0.9
                )
                // Pushed down far enough that the horizon stays off-screen, and no
                // further. Too little and the visible band climbs past the vanishing
                // point and the plane collapses to nothing; too much and the top of the
                // screen is an empty field of ground colour.
                .offset(y: geo.size.height * 0.16)

                // Distance haze. The far edge of a tilted plane is where the illusion
                // breaks, so it is faded into the ground colour rather than cut off.
                LinearGradient(
                    colors: [Ink.mapLand, Ink.mapLand.opacity(0)],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.34)
                )
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A deterministic, irregular city block pattern.
///
/// Seeded, so a screenshot can be diffed against the last one instead of reshuffling on
/// every redraw.
private enum City {
    static func draw(in context: inout GraphicsContext, size: CGSize) {
        var rng = Seeded(seed: 20_260_901)

        // Irregular street positions: a base spacing jittered per street, so blocks come
        // out different sizes without the layout losing its grid logic.
        func streets(across extent: CGFloat) -> [(pos: CGFloat, major: Bool)] {
            var result: [(CGFloat, Bool)] = []
            var x: CGFloat = -60
            var index = 0
            while x < extent + 60 {
                result.append((x, index % 4 == 0))
                x += 70 + CGFloat(rng.next() * 90)
                index += 1
            }
            return result
        }

        let vertical = streets(across: size.width)
        let horizontal = streets(across: size.height)

        // Blocks first, streets on top — the way a real basemap stacks them.
        //
        // Two passes, and the order is load-bearing: every extruded side is drawn before
        // any top face. Drawing each block complete before moving on lets the next row's
        // fill paint over the previous row's side, which erases the extrusion entirely and
        // leaves a flat diagram.
        struct Block { let rect: CGRect; let height: CGFloat; let warm: Bool; let park: Bool }
        var blocks: [Block] = []

        for r in 0..<(horizontal.count - 1) {
            for c in 0..<(vertical.count - 1) {
                let inset: CGFloat = 5
                let rect = CGRect(
                    x: vertical[c].pos + inset,
                    y: horizontal[r].pos + inset,
                    width: vertical[c + 1].pos - vertical[c].pos - inset * 2,
                    height: horizontal[r + 1].pos - horizontal[r].pos - inset * 2
                )
                guard rect.width > 6, rect.height > 6 else { continue }
                let park = rng.next() < 0.14
                blocks.append(
                    Block(
                        rect: rect,
                        // Height varies per block so a neighbourhood has a skyline instead
                        // of a uniform slab.
                        height: park ? 0 : 8 + rng.next() * 30,
                        warm: rng.next() < 0.30,
                        park: park
                    )
                )
            }
        }

        // Pass 1 — the extruded sides. On a raked plane a flat fill reads as paint on the
        // road; a darker side under a lighter top reads as a building, and that single
        // difference is most of why a game map looks like a place rather than a diagram.
        for b in blocks where !b.park {
            context.fill(
                Path(roundedRect: b.rect.offsetBy(dx: 0, dy: b.height), cornerRadius: 4, style: .continuous),
                with: .color(Ink.mapBuildingSide)
            )
        }

        // Pass 2 — the lit top faces.
        for b in blocks {
            let colour = b.park ? Ink.mapPark : (b.warm ? Ink.mapBuildingWarm : Ink.mapBuilding)
            context.fill(
                Path(roundedRect: b.rect, cornerRadius: 4, style: .continuous),
                with: .color(colour)
            )
        }

        // A river, ignoring the grid entirely. Cities are not grids; the thing that breaks
        // the grid is what makes a map look real.
        var river = Path()
        river.move(to: CGPoint(x: -40, y: size.height * 0.30))
        river.addCurve(
            to: CGPoint(x: size.width + 40, y: size.height * 0.52),
            control1: CGPoint(x: size.width * 0.35, y: size.height * 0.10),
            control2: CGPoint(x: size.width * 0.62, y: size.height * 0.74)
        )
        context.stroke(
            river,
            with: .color(Ink.mapWater),
            style: StrokeStyle(lineWidth: 46, lineCap: .round, lineJoin: .round)
        )

        for s in vertical {
            let width: CGFloat = s.major ? 17 : 10
            context.fill(
                Path(CGRect(x: s.pos - width / 2, y: 0, width: width, height: size.height)),
                with: .color(Ink.mapRoad)
            )
        }
        for s in horizontal {
            let width: CGFloat = s.major ? 17 : 10
            context.fill(
                Path(CGRect(x: 0, y: s.pos - width / 2, width: size.width, height: width)),
                with: .color(Ink.mapRoad)
            )
        }
    }

    /// Small deterministic PRNG. Not for anything that matters — only for making a
    /// placeholder city look like a city.
    private struct Seeded {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double((state >> 33) % 10_000) / 10_000
        }
    }
}
