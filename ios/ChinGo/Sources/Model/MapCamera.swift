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
    ///
    /// Opens at the engine's maximum rather than short of it. Looking down at a city from
    /// above reads as a map; looking along it reads as standing in it, and the second one is
    /// the whole point of the screen.
    private(set) var pitch: CGFloat = 70
    /// How close in.
    ///
    /// Deliberately above `CameraMath.defaultZoom`, and now at the engine's ceiling. At 17.2
    /// you can see six blocks, which is a navigation app's answer -- it tells you where you
    /// are in the city. This screen wants the opposite: the street you are standing on.
    ///
    /// As far in as the screen can go and still show what the screen is for.
    ///
    /// Two things set this, and they agree. Going further in was tried at 20.4 and looks
    /// broken without being broken: you see about forty metres of ground, which on a downtown
    /// block is entirely block interior, so the whole screen goes flat green and the roads are
    /// off the edge. And the radar rings are 80 and 150 metres across -- at 19 the inner one
    /// is already wider than the screen, so the boundary you are meant to judge distance by
    /// cannot be seen at all.
    ///
    /// The street grid and the rings are the two things that make this read as a game map
    /// rather than a lawn, and 18.2 is the closest in where both survive.
    private(set) var zoom: Double = 18.2

    /// True while the camera follows the direction of travel. A drag hands control to the
    /// user and it stays handed over until they explicitly ask for it back — a camera that
    /// silently reclaims itself mid-look is worse than one that never followed at all.
    private(set) var isFollowingCourse = true

    /// Bearing and pitch at the moment the current drag began.
    private var dragOrigin: (bearing: CLLocationDirection, pitch: CGFloat)?
    /// Zoom at the moment the current pinch began.
    private var pinchOrigin: Double?

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

    func pinch(_ scale: CGFloat) {
        let origin = pinchOrigin ?? zoom
        pinchOrigin = origin
        zoom = CameraMath.zoom(from: origin, pinchedBy: Double(scale))
    }

    func endPinch() {
        pinchOrigin = nil
    }

    /// Hand the camera back to the direction of travel.
    ///
    /// Zoom is deliberately left alone. Someone who zoomed out to get their bearings did not
    /// ask to be pushed back in, and a recentre that also re-zooms feels like being overruled.
    func recenter(course: CLLocationDirection?) {
        isFollowingCourse = true
        // Back to the opening rake, not to some other angle. This used to snap to 58 while
        // the map opens at 70, so recentring quietly flattened the view and there was no way
        // back to the angle the app starts at.
        pitch = 70
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
