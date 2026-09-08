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
/// **The ellipse is real, though.** A circle drawn in screen space under a camera raked to 78
/// degrees is the exact failure `Radar.ring` was written to avoid: it floats in front of your
/// feet instead of lying on the ground. So the shape is measured rather than assumed -- the
/// projection is asked where the centre is and where a point 150 metres north and 150 metres
/// east land, and the ellipse is built from what comes back. Under a pitched camera those two
/// are wildly different lengths, which is what makes it lie flat.
struct RadarPulse: View {
    /// Where you are. The centre of everything here.
    var centre: CLLocationCoordinate2D
    /// Lets the ellipse be measured against the live camera.
    var projection: MapProjection
    /// Off when you are hidden. A radar that keeps sweeping while nobody can see you is
    /// saying the opposite of what is true.
    var discoverable: Bool

    /// Three, staggered by a third of a cycle each, so the sweep is continuous rather than a
    /// single ring you wait for.
    private static let rings = 3
    /// Seconds for one ring to travel from your feet to the discovery edge.
    private static let period: Double = 2.4

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

                if discoverable, let shape = shape {
                    let now = timeline.date.timeIntervalSinceReferenceDate

                    ZStack {
                        ForEach(0..<Self.rings, id: \.self) { index in
                            let phase = travel(at: now, ring: index)

                            Ellipse()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: shape.width, height: shape.height)
                                // The frame is the destination, so 1 is the discovery edge.
                                .scaleEffect(max(phase, 0.02))
                                // Fades as it goes, and faster than it travels -- a ring that
                                // is still bright when it arrives reads as a boundary being
                                // drawn rather than as a signal that has run out of room.
                                .opacity((1 - phase) * 0.85)
                                .position(shape.centre)
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
        let offset = Double(ring) / Double(Self.rings) * Self.period
        return ((now + offset).truncatingRemainder(dividingBy: Self.period)) / Self.period
    }

    /// The discovery ring as it actually lands on screen: centre, and the two semi-axes.
    ///
    /// Nil before the map is up, and nil if the far edge projects to nonsense -- which happens
    /// when the ring runs past the horizon at this pitch, and is the honest answer rather than
    /// a guess.
    private var shape: (centre: CGPoint, width: CGFloat, height: CGFloat)? {
        guard let here = projection.point(for: centre) else { return nil }

        let metres = Radar.discoveryMetres
        // Degrees per metre. Longitude shrinks with latitude, which matters at the poles and
        // is free to get right.
        let north = metres / 111_320
        let east = metres / (111_320 * max(cos(centre.latitude * .pi / 180), 0.01))

        guard
            let top = projection.point(for: .init(latitude: centre.latitude + north, longitude: centre.longitude)),
            let bottom = projection.point(for: .init(latitude: centre.latitude - north, longitude: centre.longitude)),
            let side = projection.point(for: .init(latitude: centre.latitude, longitude: centre.longitude + east))
        else { return nil }

        var height = abs(bottom.y - top.y)
        var width = abs(side.x - here.x) * 2
        guard height.isFinite, width.isFinite, height > 1, width > 1 else { return nil }

        // Scaled down to something you can see, and this is the one place the sweep stops
        // being true to the ground.
        //
        // At this zoom and pitch the real 150-metre ring is about 1100 points across on a
        // 402-point screen, so a pulse drawn at true scale is a faint arc crossing the frame
        // and leaving -- geometrically perfect and completely illegible. It reads as a
        // rendering artefact rather than as a radar.
        //
        // The two rings that *are* on the ground already carry the real distances, and they
        // are the ones anybody navigates by. This is a signal that something is scanning, so
        // it is sized to be read. The aspect ratio and the centre stay measured, which is what
        // keeps it lying flat instead of standing up in front of the bear.
        let target: CGFloat = 300
        if width > target {
            height *= target / width
            width = target
        }

        // Centred on your feet, not on the true ellipse midpoint.
        //
        // The midpoint is the honest answer for a ring that is actually 150 metres across: at
        // this pitch the far half compresses so much that the centre sits a long way up the
        // screen, near the horizon. Once the size stopped being true to the ground -- see
        // above -- keeping the centre true stopped being meaningful and started being wrong,
        // because it drew a small ring floating in the distance rather than a sweep leaving
        // the bear.
        return (here, width, height)
    }
}
