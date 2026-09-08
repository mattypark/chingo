import CoreLocation
import Foundation
import ChinGoDesign

/// The two circles on the ground around you.
///
/// Pokémon GO draws two and they mean different things: an outer ring for the area things
/// appear in, and an inner one for the range you can actually reach. Copying that split is
/// worth more than copying either circle on its own, because one ring answers two questions
/// badly -- Monster Hunter Now shipped a single ring covering two different distances and the
/// community complaint was exactly that nobody could tell which number they were looking at.
///
/// **They are constants, not indicators.** Neither ring changes when somebody walks into it.
/// Niantic never flashes the ring; the *world* changes against it, and the ring stays put as
/// the thing you measure by. A ring that reacts to events becomes noise within a day.
enum Radar {

    /// Where somebody stops being drawn at all. Matches `GeoCell.degreesPerCell`, which the
    /// engine already describes as "the radius a memory should surface at" -- the app has
    /// been carrying this number as its idea of nearby since before there was a map.
    static let discoveryMetres: Double = 150

    /// Close enough to walk over and say something. Pokémon GO settled on 80m for the same
    /// job after trying 40 and reverting under enough pressure that they made 80 permanent.
    static let interactionMetres: Double = 80

    /// Where somebody already inside stops being drawn.
    ///
    /// A third further out than the radius that let them in. Phone GPS in a city drifts five
    /// to twenty metres and does not hold still, so without a gap anybody standing near the
    /// boundary strobes on and off the map several times a minute. Pikmin Bloom uses 90m in
    /// and 120m out for exactly this, and it is the sort of thing that reads as a haunting
    /// bug rather than as a threshold if you leave it out.
    static let releaseMetres: Double = discoveryMetres * 1.33

    /// A ring of points at a true distance on the sphere.
    ///
    /// Geodesic rather than a screen-space ellipse, because the ring has to lie on the road.
    /// Under a raked camera a circle projects to an ellipse whose centre is *not* the player:
    /// at 70 degrees of pitch with a 100m radius the true centre sits about a third of its own
    /// semi-height below the dot, so a screen ellipse drawn around the player reads as
    /// floating in front of their feet. Handing real coordinates to MapLibre makes that the
    /// projection's problem, which it already solves exactly.
    static func ring(
        around centre: CLLocationCoordinate2D,
        metres: Double,
        segments: Int = 96
    ) -> [CLLocationCoordinate2D] {
        // IUGG mean Earth radius.
        let earth = 6_371_008.8
        let angular = metres / earth
        let lat = centre.latitude * .pi / 180
        let lon = centre.longitude * .pi / 180

        return (0...segments).map { step in
            let bearing = 2 * Double.pi * Double(step) / Double(segments)
            let ringLat = asin(
                sin(lat) * cos(angular) + cos(lat) * sin(angular) * cos(bearing)
            )
            let ringLon = lon + atan2(
                sin(bearing) * sin(angular) * cos(lat),
                cos(angular) - sin(lat) * sin(ringLat)
            )
            return CLLocationCoordinate2D(
                latitude: ringLat * 180 / .pi,
                longitude: ringLon * 180 / .pi
            )
        }
    }
}

/// What the map needs to draw the rings this frame.
struct RadarState: Equatable {
    let centre: CLLocationCoordinate2D
    /// Off means you are hidden. The rings stay drawn either way -- see `MapLibreMap`.
    let discoverable: Bool

    static func == (a: RadarState, b: RadarState) -> Bool {
        a.discoverable == b.discoverable
            && a.centre.latitude == b.centre.latitude
            && a.centre.longitude == b.centre.longitude
    }
}
