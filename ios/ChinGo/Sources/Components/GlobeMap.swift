import SwiftUI
import MapKit
import CoreLocation
import ChinGoDesign

/// One friend, somewhere on the planet.
struct GlobePin: Identifiable, Equatable {
    let id: String
    let handle: String
    let coordinate: CLLocationCoordinate2D
    /// Seconds since the fix. Shown, never hidden -- a dot with no age on it reads as "now",
    /// and it usually is not.
    let age: TimeInterval
    let accent: Int

    /// Equality is about what is drawn, and `age` deliberately is not part of it. It is
    /// derived from `Date.now` every time the list is rebuilt, so including it means two
    /// identical pins are never equal and anything keyed on "did this change" fires forever.
    static func == (a: GlobePin, b: GlobePin) -> Bool {
        a.id == b.id
            && a.accent == b.accent
            && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude
    }
}

/// The planet, as a planet.
///
/// **MapKit, not MapLibre, and that is the point.** Since iOS 16 `MKMapView` draws a real
/// globe when the camera is far enough out -- a lit sphere on a starfield, with the terminator
/// and the atmosphere, spinning under a drag and swelling under a pinch. That is what Find My
/// is: not a clever custom renderer, this view with people on it. Rebuilding it on a flat
/// vector map would mean writing an orthographic projection, a lighting model and a horizon
/// clip to arrive somewhere worse than one line of configuration.
///
/// The trade is worth naming: this is the one screen not drawn in the app's own palette.
/// Satellite imagery is photographic and everything else here is flat colour with a hard
/// outline. It earns the exception by being a different kind of thing -- the street map is a
/// board you play on, this is a look at the actual Earth -- and the chrome over it stays ours,
/// so the sticker language still frames it.
///
/// It also retires a bug rather than fixing it. The MapLibre version's friend pins never
/// rendered and I never found why; these are `MKAnnotationView`s, which is a different
/// mechanism end to end.
struct GlobeMap: UIViewRepresentable {
    var pins: [GlobePin]
    /// Bumped by the caller to re-frame the view on everybody.
    var fitToken: Int
    /// Where each friend lands on screen, so the caller can draw them itself.
    var projection: GlobeProjection
    /// Which of the three looks to draw.
    var look: GlobeLook
    /// Somebody to fly to. Changing `focusToken` is what triggers the flight, so tapping the
    /// same person twice flies back to them rather than doing nothing.
    var focus: GlobePin?
    var focusToken: Int

    /// Far enough out that MapKit switches to the globe.
    ///
    /// Below roughly a quarter of this it flattens into an ordinary map, which is the right
    /// behaviour -- you zoom in and the planet becomes a place -- but it means the opening
    /// altitude has to be generous or the screen the feature is named after never appears.
    static let globeAltitude: CLLocationDistance = 42_000_000

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        // Imagery with labels. Plain imagery loses the continent names, and on a globe with
        // three people on it those names are most of what tells you where you are looking.
        map.preferredConfiguration = look.configuration
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: -30),
            fromDistance: Self.globeAltitude,
            pitch: 0,
            heading: 0
        )
        return map
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        projection.attach(map)

        if context.coordinator.look != look {
            context.coordinator.look = look
            map.preferredConfiguration = look.configuration
        }

        if context.coordinator.lastFocus != focusToken {
            context.coordinator.lastFocus = focusToken
            if let focus {
                map.setCamera(
                    MKMapCamera(
                        lookingAtCenter: focus.coordinate,
                        // Far enough that the limb still curves. At 4,000 km the token sits
                        // unmistakably over a country but MapKit has flattened into an
                        // ordinary map, and the screen stops being the thing it is for.
                        // 12,000 km keeps the sphere and still lands you on a place.
                        fromDistance: 12_000_000,
                        pitch: 0,
                        heading: 0
                    ),
                    animated: true
                )
            }
        } else if context.coordinator.lastFit != fitToken {
            context.coordinator.lastFit = fitToken
            context.coordinator.fit(map)
        }
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MKMapViewDelegate {
        var parent: GlobeMap
        var lastFit = Int.min
        var lastFocus = Int.min
        var look: GlobeLook?

        init(_ parent: GlobeMap) { self.parent = parent }

        /// Every camera move re-places the tokens drawn over the map.
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.projection.advance()
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.projection.advance()
        }

        /// Frames everybody, or leaves the globe alone when there is nobody to frame.
        ///
        /// Deliberately does not zoom all the way in on a crowd standing in one city. The
        /// screen is called the globe and its job is "where in the world" -- dropping straight
        /// to street level would answer a question nobody opened it to ask.
        ///
        /// It also cannot always succeed, and that is a fact about the Earth rather than a
        /// limitation here: two people more than a hemisphere apart are not simultaneously
        /// visible on a sphere at any distance, and MapKit clamps how far the camera can pull
        /// back anyway. That is what the row of faces at the bottom of the screen is for.
        func fit(_ mapView: MKMapView) {
            let coordinates = parent.pins.map(\.coordinate)
            guard !coordinates.isEmpty else { return }

            if coordinates.count == 1, let only = coordinates.first {
                mapView.setCamera(
                    MKMapCamera(lookingAtCenter: only, fromDistance: 6_000_000, pitch: 0, heading: 0),
                    animated: true
                )
                return
            }

            // The midpoint in three dimensions, not the average of the numbers. Averaging
            // longitudes puts somebody in Tokyo and somebody in San Francisco in the middle of
            // Asia, because the numbers wrap and the mean does not know that.
            var (x, y, z) = (0.0, 0.0, 0.0)
            for c in coordinates {
                let lat = c.latitude * .pi / 180
                let lon = c.longitude * .pi / 180
                x += cos(lat) * cos(lon)
                y += cos(lat) * sin(lon)
                z += sin(lat)
            }
            let count = Double(coordinates.count)
            (x, y, z) = (x / count, y / count, z / count)
            let centre = CLLocationCoordinate2D(
                latitude: atan2(z, (x * x + y * y).squareRoot()) * 180 / .pi,
                longitude: atan2(y, x) * 180 / .pi
            )

            // How far apart the two furthest people are decides how far back to stand.
            var spread: CLLocationDistance = 0
            for a in coordinates {
                for b in coordinates {
                    spread = max(spread, CLLocation(latitude: a.latitude, longitude: a.longitude)
                        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)))
                }
            }

            mapView.setCamera(
                MKMapCamera(
                    lookingAtCenter: centre,
                    // 5x, and the number was measured rather than picked. Distance does not
                    // map to visible extent linearly once the camera is far enough out for the
                    // sphere to curve away: at 2.4 a Lisbon-to-Seoul spread framed central
                    // Asia with both of them over the horizon, and at 3.5 they projected to
                    // x = -49 and x = 442 on a 402-point screen -- placed correctly, forty
                    // points outside the frame at each end. 5x pushes that spread to the
                    // clamp, which is the whole planet, where everybody is comfortably inside
                    // the disc. That is the right answer for a "show me everybody" button.
                    fromDistance: min(max(spread * 5, 3_000_000), GlobeMap.globeAltitude),
                    pitch: 0,
                    heading: 0
                ),
                animated: true
            )
        }
    }
}

/// Where a coordinate lands on screen, and whether it is on the near side of the planet.
///
/// The same trick the street map uses for its reveal card: ask the map view where a coordinate
/// is and draw a SwiftUI view there, rather than handing the renderer something to draw. Here
/// it is not a preference -- annotations do not work at all under realistic elevation -- but it
/// pays for itself anyway, because these tokens are the app's own sticker language and getting
/// that out of `MKAnnotationView` would mean compositing bitmaps by hand.
@MainActor
@Observable
final class GlobeProjection {
    private weak var mapView: MKMapView?
    private(set) var tick = 0

    func attach(_ map: MKMapView) { mapView = map }

    func advance() { tick &+= 1 }

    /// Screen point, or nil when the coordinate is round the back.
    ///
    /// The back-of-the-globe check is the part that cannot be skipped. `convert` happily
    /// returns a point for a coordinate on the far side of the Earth, so without it Seoul is
    /// drawn on top of the Atlantic while the camera is over Portugal -- people floating over
    /// the wrong ocean, which is worse than not drawing them.
    func point(for coordinate: CLLocationCoordinate2D) -> CGPoint? {
        guard let mapView else { return nil }

        // Central angle between the camera's centre and the pin. Past a right angle the pin is
        // behind the horizon; 82 degrees rather than 90 so a token does not half-emerge from
        // the limb.
        let centre = mapView.camera.centerCoordinate
        let (lat1, lon1) = (centre.latitude * .pi / 180, centre.longitude * .pi / 180)
        let (lat2, lon2) = (coordinate.latitude * .pi / 180, coordinate.longitude * .pi / 180)
        let cosAngle = sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(lon2 - lon1)
        guard cosAngle > cos(82 * .pi / 180) else { return nil }

        let point = mapView.convert(coordinate, toPointTo: mapView)
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return point
    }
}
