import CoreLocation
import Observation
import ChinGoEngine

/// Where you are, and — much more often — which cell you are in.
///
/// Two deliberate limits:
///
///   * **When in use only.** No background updates, no significant-change monitoring, no
///     `allowsBackgroundLocationUpdates`. A social map app asking for Always is the exact
///     posture that has regulators writing letters, and ChinGo does not need it: discovery
///     is a per-session switch, so there is nothing to track while the app is closed.
///   * **The precise coordinate never leaves this object** except into a memory row, which
///     is local and owner-only. Everything the app sends anywhere is `currentCell`.
@MainActor
@Observable
final class LocationService: NSObject {

    private let manager = CLLocationManager()

    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var currentCell: GeoCell?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// Direction of travel, in degrees. Nil while stationary.
    ///
    /// `course` is meaningless near zero speed — CoreLocation reports whatever the last
    /// scrap of movement suggested — so it is only published above a walking threshold and
    /// only when CoreLocation itself says the value is trustworthy. Rotating a map from an
    /// untrusted course is how a stationary phone ends up spinning the whole world.
    private(set) var course: CLLocationDirection?
    /// A human-readable name for where you are, for the label on a catch. Reverse geocoding
    /// is rate-limited by the system, so it is refreshed per cell rather than per fix.
    private(set) var placeLabel: String?

    private var lastGeocodedCell: GeoCell?
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        // A social app does not need best-possible accuracy, and asking for it drains the
        // battery of a phone that is out all evening. Hundred metres is finer than a cell.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 25
        authorization = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    /// The simulator has no GPS unless a location is set in the scheme, and the app has to
    /// stay drivable without one. This is a working fallback, not a stub.
    nonisolated static let fallback = CLLocationCoordinate2D(latitude: 37.7595, longitude: -122.4271)

    var coordinateOrFallback: CLLocationCoordinate2D { coordinate ?? Self.fallback }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        Task { @MainActor in
            authorization = status
            start()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            coordinate = last.coordinate

            let moving = last.speed > 0.4                 // m/s, about a slow walk
            let trustworthy = last.courseAccuracy >= 0 && last.courseAccuracy < 45
            course = (moving && trustworthy) ? last.course : nil

            let cell = GeoCell(
                latitude: last.coordinate.latitude,
                longitude: last.coordinate.longitude
            )
            currentCell = cell
            await refreshPlaceLabel(for: cell, at: last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Not fatal and not worth surfacing: a fix will usually arrive on the next update,
        // and the app has a working fallback in the meantime.
        Task { @MainActor in
            if coordinate == nil { currentCell = GeoCell(
                latitude: Self.fallback.latitude,
                longitude: Self.fallback.longitude
            ) }
        }
    }

    @MainActor
    private func refreshPlaceLabel(for cell: GeoCell, at location: CLLocation) async {
        guard cell != lastGeocodedCell else { return }
        lastGeocodedCell = cell
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return }
        placeLabel = placemark.name ?? placemark.subLocality ?? placemark.locality
    }
}
