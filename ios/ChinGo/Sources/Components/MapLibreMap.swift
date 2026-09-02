import SwiftUI
import MapLibre
import CoreLocation
import ChinGoDesign

/// The real world.
///
/// Replaces the hand-drawn Canvas placeholder. Streets, buildings, parks and shops come from
/// OpenStreetMap through OpenFreeMap's free vector tiles, styled by `chingo-style.json` with
/// the same `Ink` tokens the chrome uses — the basemap and the interface floating above it
/// have to read as one product, not as an app sitting on top of somebody else's map.
///
/// **Why this wraps `MLNMapView` by hand** rather than using MapLibre's official SwiftUI DSL:
/// that package is pre-1.0 and its consumers pin it to `main`, so breaking API changes arrive
/// with no version to hold. This is about 100 lines and leaves one versioned dependency.
///
/// **Why it does not use MapLibre's own location tracking**: `LocationService` already owns
/// location for the whole app, including the coarsening that the privacy model depends on.
/// Two location sources would eventually disagree, and the one that disagrees silently is the
/// one that leaks. So the camera is driven from our coordinate, and MapLibre never starts a
/// `CLLocationManager` of its own.
struct MapLibreMap: UIViewRepresentable {

    /// Where to point the camera.
    var coordinate: CLLocationCoordinate2D
    /// Compass bearing the camera faces. Driven by `MapCamera`, which is either following
    /// the direction of travel or being dragged by the user.
    var bearing: CLLocationDirection
    /// How far back the camera is raked. 0 is a flat document; 60 is standing in a world.
    var pitch: CGFloat
    /// How close in. Converted to a camera altitude through MapLibre's own helper, because
    /// altitude and zoom are only equivalent at a given pitch and latitude — computing it by
    /// hand is how a camera ends up either underground or looking at the whole planet.
    var zoom: Double

    func makeUIView(context: Context) -> MLNMapView {
        let style = Bundle.main.url(forResource: "chingo-style", withExtension: "json")
        let map = MLNMapView(frame: .zero, styleURL: style)

        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Our own puck is drawn on top, centred and fixed. MapLibre's blue dot would be a
        // second, slightly-disagreeing representation of the same fact.
        map.showsUserLocation = false
        map.userTrackingMode = .none

        // The player stays put and the world moves. That single decision is most of what
        // makes a map screen feel like a game rather than a navigation tool.
        // Every camera gesture is handled by MapCamera and applied through setCamera, so
        // MapLibre's own gesture recognisers are all off. Leaving them on means two things
        // driving one camera, which shows up as the view snapping back mid-drag.
        //
        // Rotation in particular has to be ours: MapLibre's built-in rotate is a two-finger
        // twist, and looking around should cost one thumb.
        map.allowsScrolling = false
        map.allowsRotating = false
        map.allowsTilting = false
        map.allowsZooming = false

        map.compassView.isHidden = true
        map.logoView.isHidden = true
        // The attribution button stays. OpenStreetMap's licence requires credit, and it is
        // also the only affordance telling a curious user where the map came from.
        map.attributionButton.tintColor = UIColor(Ink.textFaint)

        map.setCamera(camera(for: map, heading: bearing), animated: false)

        return map
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Holds the zoom the map was last given. `MLNMapView.zoomLevel` is derived from altitude
    /// and drifts by a hair, so comparing against it directly reports a change every frame.
    final class Coordinator {
        var lastZoom: Double = .nan
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let lastZoom = context.coordinator.lastZoom
        context.coordinator.lastZoom = zoom
        // A drag must land on the same frame it happens on, or looking around feels like
        // steering a boat. Position changes still ease, because a camera that snaps to every
        // GPS fix reads as jitter even when the fixes are good.
        // Any live gesture lands on the frame it happens on. Easing a pinch makes the map
        // feel like it is catching up with the fingers rather than following them.
        let gesturing = abs(map.camera.heading - bearing) > 0.5
            || abs(map.camera.pitch - pitch) > 0.5
            || abs(lastZoom - zoom) > 0.001
        map.setCamera(
            camera(for: map, heading: bearing),
            withDuration: gesturing ? 0 : 0.85,
            animationTimingFunction: nil
        )
    }

    private func camera(for map: MLNMapView, heading: CLLocationDirection) -> MLNMapCamera {
        // The view can be zero-sized on the very first layout pass, and an altitude derived
        // from a zero size is meaningless — so fall back to the screen until it isn't.
        let size = map.bounds.size == .zero ? UIScreen.main.bounds.size : map.bounds.size
        let altitude = MLNAltitudeForZoomLevel(zoom, pitch, coordinate.latitude, size)
        return MLNMapCamera(
            lookingAtCenter: coordinate,
            altitude: altitude,
            pitch: pitch,
            heading: heading
        )
    }
}
