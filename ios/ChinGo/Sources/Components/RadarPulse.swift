import SwiftUI
import CoreLocation
import ChinGoDesign
import ChinGoEngine

/// The radar going out.
///
/// Two rings already sit on the ground as real geometry -- 80 metres and 150 -- and they are
/// true to the world but they are also completely still, which makes the boundary look drawn
/// rather than active. This is the thing Pokemon GO does that makes a radar read as a radar:
/// a ring leaves you and travels out to the edge, over and over.
///
/// **Drawn in SwiftUI, not as map geometry, and that is not laziness.** MapLibre Native has no
/// animated-geometry primitive. The only way to do this on the map itself is to reassign
/// `MLNShapeSource.shape` every frame, which re-tessellates a 97-point polyline and re-uploads
/// its vertex buffer sixty times a second, for a circle. The paint properties cannot help
/// either: `MLNTransition` can cross-fade an opacity but has nothing that animates a radius.
///
/// It is nearly free here for a reason peculiar to this screen -- the player is pinned dead
/// centre by construction, so there is no marker to track.
///
/// **The ring is painted on the road, not on the screen.** This used to be a SwiftUI
/// `Ellipse()` sized from two measured axes -- how far 150 metres north reached, and how far
/// 150 metres east -- then scaled to a fixed 300 points and centred on the player's feet.
/// Three things were wrong with that, and they compounded:
///
/// - **An axis-aligned ellipse ignores bearing.** A circle on the ground projects to an
///   ellipse whose long axis follows the horizon, so it rotates as you turn. Measuring only
///   north-south and east-west pins the ellipse upright, and it visibly slides out from under
///   the ring painted on the ground beside it as soon as the camera is not facing north.
/// - **Centring on the feet is not where the ellipse is.** Under a raked camera the far half
///   of a circle compresses much more than the near half, so the true centre sits well up the
///   screen. The old code knew this and chose the feet anyway, which is why the shape sat in
///   front of the bear rather than around it.
/// - **Rescaling to 300 points severs it from the world.** Once the size no longer means a
///   distance, the ring stops agreeing with the two real ones underneath it.
///
/// So the pulse is now the same geometry as the still rings: `Radar.ring` gives a real
/// geodesic circle at the radius the pulse has reached, every point goes through the map's own
/// projection, and the result is stroked as a path. Pitch, bearing and zoom are then the
/// projection's problem, which it already solves exactly -- and the ring lies on the road at
/// every angle, which is the whole thing Pokemon GO's does that makes it read as ground.
struct RadarPulse: View {
    /// Where you are. The centre of everything here.
    var centre: CLLocationCoordinate2D
    /// Lets the ellipse be measured against the live camera.
    var projection: MapProjection
    /// Off when you are hidden. A radar that keeps sweeping while nobody can see you is
    /// saying the opposite of what is true.
    var discoverable: Bool

    /// Three, so the sweep is continuous rather than a single ring you wait for.
    private static let rings = 3

    /// Seconds for one ring to travel from your feet to the discovery edge.
    ///
    /// 5.5 rather than 2.4. At the old rate a ring crossed 150 metres of ground every two
    /// seconds, which is a scanner working hard at something; this is ambience, and the two
    /// still rings underneath are what actually carry the distances. A slow sweep reads as a
    /// place breathing, a fast one as a progress indicator.
    private static let period: Double = 5.5

    /// Where each ring sits in the cycle, as a fraction of it.
    ///
    /// Deliberately not thirds. Evenly spaced rings arrive on a beat, and three objects
    /// arriving on a beat is a metronome -- the eye locks onto the rhythm and then the sweep
    /// is a loading spinner rather than something the world is doing. Uneven gaps read as
    /// unsynchronised, which is what `Motion`'s ambience section asks of every idle here.
    private static let offsets: [Double] = [0, 0.41, 0.73]

    var body: some View {
        // Driven by a clock rather than by `withAnimation`, and that is a fix rather than a
        // preference.
        //
        // The obvious version is a `@State` flag toggled in `onAppear` with a `repeatForever`
        // animation on it. It does not survive here: this view re-runs its body on every
        // rendered frame, because it has to re-measure the ellipse against a moving camera,
        // and re-applying an `.animation` modifier that often drops the repeat. The rings were
        // present, correctly sized, and frozen.
        //
        // A `TimelineView` has no such dependency -- the phase is a function of the current
        // time, so body churn cannot disturb it. `Clouds` drives its drift the same way for
        // the same reason.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: Motion.reduceMotion)) { timeline in
            GeometryReader { _ in
                // Reading `tick` is what re-measures the ellipse as the camera moves.
                let _ = projection.tick

                if discoverable {
                    let now = timeline.date.timeIntervalSinceReferenceDate

                    ZStack {
                        ForEach(0..<Self.rings, id: \.self) { index in
                            let phase = travel(at: now, ring: index)

                            if let path = ring(atPhase: phase) {
                                path.stroke(.white, lineWidth: 3)
                                    // Fades as it goes, and faster than it travels -- a ring
                                    // that is still bright when it arrives reads as a boundary
                                    // being drawn rather than as a signal that ran out of room.
                                    .opacity((1 - phase) * 0.85)
                            }
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// How far along its journey one ring is, 0 at your feet and 1 at the edge.
    ///
    /// Reduced motion parks every ring at the edge instead of stopping them mid-flight: a
    /// frozen half-expanded circle is a rendering fault, and the outer ring is the one piece
    /// of information the sweep was carrying anyway.
    private func travel(at now: Double, ring: Int) -> Double {
        guard !Motion.reduceMotion else { return 1 }
        let offset = Self.offsets[ring % Self.offsets.count] * Self.period
        return ((now + offset).truncatingRemainder(dividingBy: Self.period)) / Self.period
    }

    /// The sweep at one moment, as it lands on the road.
    ///
    /// Built from the same geodesic circle the still rings use, so a ring at 80 metres here
    /// and the painted 80-metre ring underneath it are the same shape by construction rather
    /// than by two pieces of code agreeing.
    ///
    /// Nil rather than clamped when any part of the circle runs past the horizon. A point
    /// beyond the vanishing line projects to a coordinate thousands of points away, and
    /// joining it to its neighbours draws a spike across the screen -- so the honest answer
    /// for a ring that does not entirely fit on the ground is to skip that ring for a frame.
    private func ring(atPhase phase: Double) -> Path? {
        // Never zero. A circle of radius nothing is a point, and the first frames of a sweep
        // should read as leaving the bear rather than as appearing on top of it.
        let metres = max(phase * Radar.discoveryMetres, 2)
        guard let here = projection.point(for: centre) else { return nil }

        // How far off screen a point may land before the ring is judged to have run past the
        // horizon. Generous, because most of a large ring is legitimately outside the frame
        // under a raked camera; it is the runaway projections this is catching.
        let limit: CGFloat = 4000

        var path = Path()
        var started = false

        for coordinate in Radar.ring(around: centre, metres: metres, segments: 72) {
            guard let point = projection.point(for: coordinate) else { return nil }
            guard abs(point.x - here.x) < limit, abs(point.y - here.y) < limit else { return nil }

            if started {
                path.addLine(to: point)
            } else {
                path.move(to: point)
                started = true
            }
        }

        guard started else { return nil }
        path.closeSubpath()
        return path
    }
}
