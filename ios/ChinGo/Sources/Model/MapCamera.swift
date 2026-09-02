import Foundation
import CoreLocation
import SwiftUI
import ChinGoEngine

/// Where the camera is looking.
///
/// Separate from `LocationService` on purpose: that owns where the user *is*, this owns where
/// they are *looking*. Conflating the two is how a map ends up snapping the view back to
/// north every time a GPS fix lands, which feels like the app fighting your thumb.
@MainActor
@Observable
final class MapCamera {

    /// Compass bearing the camera faces, in degrees.
    private(set) var bearing: CLLocationDirection = 0
    /// How far the camera is raked back. 0 looks straight down; 70 is nearly at street level.
    private(set) var pitch: CGFloat = 58

    /// True while the camera follows the direction of travel. A drag hands control to the
    /// user and it stays handed over until they explicitly ask for it back — a camera that
    /// silently reclaims itself mid-look is worse than one that never followed at all.
    private(set) var isFollowingCourse = true

    /// Bearing and pitch at the moment the current drag began.
    private var dragOrigin: (bearing: CLLocationDirection, pitch: CGFloat)?

    func drag(_ translation: CGSize) {
        let origin = dragOrigin ?? (bearing, pitch)
        dragOrigin = origin
        isFollowingCourse = false

        bearing = CameraMath.bearing(from: origin.bearing, draggedBy: Double(translation.width))
        pitch = CGFloat(CameraMath.pitch(from: Double(origin.pitch), draggedBy: Double(translation.height)))
    }

    func endDrag() {
        dragOrigin = nil
    }

    /// Hand the camera back to the direction of travel.
    func recenter(course: CLLocationDirection?) {
        isFollowingCourse = true
        pitch = 58
        bearing = course ?? 0
    }

    /// Called on every location update. Ignored once the user has taken over.
    func follow(course: CLLocationDirection?) {
        guard isFollowingCourse, let course else { return }
        bearing = course
    }

    /// How far the view is turned from north, for the compass needle.
    var isOffNorth: Bool {
        abs(CameraMath.shortestTurn(from: 0, to: bearing)) > 2
    }
}
