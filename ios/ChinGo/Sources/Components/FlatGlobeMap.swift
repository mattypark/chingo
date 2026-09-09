import SwiftUI
import MapLibre
import CoreLocation
import ChinGoDesign

/// The city, drawn rather than photographed.
///
/// MapLibre with our own style, which is the only way to get this look: MapKit renders Apple's
/// map and offers no way to recolour it, so "less realistic" there stops at turning satellite
/// imagery off and still leaves Apple's blue-and-green. This is the same basemap and the same
/// pipeline the street map already uses, painted from a second palette -- so the two screens
/// stay one product without pretending to be the same surface.
///
/// **It is quiet on purpose.** The street map shouts: saturated green, dark ribbons, yellow
/// edges, roads at two and a half times their cartographic width. Every one of those exists so
/// the ground reads as a game board at walking scale. Pull back to a whole city and they
/// become noise -- there is nothing to play on at that zoom, only somebody to find. So here
/// the paper is near-white, the roads are white with the faintest warm edge, and the only
/// saturated things on screen are people.
///
/// **Flat and north-up.** The street map is raked because you are standing in it. There is no
/// standing in a city seen whole, and a pitched city map is just a city map you have to think
/// about.
struct FlatGlobeMap: UIViewRepresentable {
    var accent: Accent
    /// Where each friend lands on screen, so the caller can draw them itself.
    var projection: GlobeProjection
    var focus: GlobePin?
    var focusToken: Int
    /// Bumped to step the zoom, and the direction that step goes. Same shape as the other
    /// tokens here: the view watches a counter rather than being told to do things, because
    /// a `UIViewRepresentable` is re-made constantly and an imperative call would fire on
    /// every rebuild.
    var zoomToken: Int = 0
    var zoomDirection: Double = 0

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: MapStyle.url(for: accent, kind: .flat))
        map.delegate = context.coordinator
        map.backgroundColor = UIColor(MapStyle.ground(for: accent, kind: .flat))

        // Unlike the street map, every gesture here belongs to the map. That one is a camera
        // the app drives and the player nudges; this one is a thing you actually move around.
        map.allowsScrolling = true
        map.allowsZooming = true
        map.allowsRotating = false
        map.allowsTilting = false
        map.minimumZoomLevel = 2
        map.maximumZoomLevel = 17
        // The MapLibre wordmark comes off; the attribution button stays. That split is a
        // licence fact rather than a preference, and it is worth stating because getting it
        // backwards is either a rude UI or a breach.
        //
        // MapLibre Native is BSD-2 and its logo carries no attribution requirement -- that was
        // a Mapbox SDK term, and this is not Mapbox. The OpenStreetMap credit behind the (i)
        // *is* required, under ODbL. The OSM Foundation's own attribution guidelines allow it
        // to live "from an '(i)' button in the corner of the map or an 'About' option in a
        // menu" rather than permanently on the map, which is exactly what this is.
        map.logoView.isHidden = true
        map.attributionButton.isHidden = false
        map.compassView.isHidden = true
        map.attributionButtonMargins = CGPoint(x: 8, y: 142)
        return map
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.parent = self
        projection.attach(map)

        if context.coordinator.lastZoom != zoomToken {
            context.coordinator.lastZoom = zoomToken
            map.setZoomLevel(map.zoomLevel + (zoomDirection > 0 ? 1.4 : -1.4), animated: true)
        }

        if context.coordinator.lastFocus != focusToken {
            context.coordinator.lastFocus = focusToken
            if let focus {
                // City scale. Close enough that the token is over a place with a name, far
                // enough that it is not a claim about which street somebody is on -- the
                // position behind it does not support that and should not look like it does.
                map.setCenter(focus.coordinate, zoomLevel: 10, animated: true)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
        var parent: FlatGlobeMap
        var lastFocus = Int.min
        var lastZoom = 0

        init(_ parent: FlatGlobeMap) { self.parent = parent }

        /// Every frame re-places the tokens drawn over the map. Same mechanism the street
        /// map's reveal card uses.
        func mapViewDidFinishRenderingFrame(_ mapView: MLNMapView, fullyRendered: Bool) {
            parent.projection.advance()
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // The camera the caller asked for, applied once the style is up. A style declares
            // its own default centre and it clobbers whatever was set before loading -- which
            // is how the street map once opened over the Atlantic.
            guard let focus = parent.focus else { return }
            DispatchQueue.main.async { [weak mapView] in
                mapView?.setCenter(focus.coordinate, zoomLevel: 10, animated: false)
            }
        }
    }
}
