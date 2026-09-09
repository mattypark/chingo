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
    private(set) var pitch: CGFloat = 78
    /// How close in.
    ///
    /// Deliberately above `CameraMath.defaultZoom`, and now at the engine's ceiling. At 17.2
    /// you can see six blocks, which is a navigation app's answer -- it tells you where you
    /// are in the city. This screen wants the opposite: the street you are standing on.
    ///
    /// As far in as the screen can go and still show what the screen is for.
    ///
    /// This used to be 18.2, held there by two things. Going further in was tried at 20.4 and
    /// looked broken without being broken: you see about forty metres of ground, which on a
    /// downtown block is entirely block interior, so the whole screen went flat and the roads
    /// were off the edge. And the radar rings are 80 and 150 metres across, so past about 19
    /// neither fits on screen as a circle.
    ///
    /// The first has stopped being true: the roads are 2.6x their navigation width now, so
    /// there is street on screen at zooms where there used not to be. The second still holds,
    /// and this trades it away deliberately. Past about 19 a ring stops being a circle you can
    /// see and becomes an arc crossing the ground, which still reads as a boundary -- and the
    /// interaction ring was never the real signal for crossing it anyway. A card appearing
    /// over somebody's head is.
    ///
    /// Lighting the ground inside the discovery ring was tried as a way to keep "am I inside
    /// it" legible without the whole circle. It does not work at this zoom for the reason the
    /// zoom is the problem: the entire visible frame is inside the ring, so the fill has no
    /// edge in it and only washes the palette out.
    ///
    /// So: forty metres is still too far -- at 20 the frame is one intersection and nothing
    /// else -- but 18.8 gives about fifty-five metres across, which is your street and the
    /// corners at either end of it.
    private(set) var zoom: Double = 18.8

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

    /// One step in or out, for the gestures that are not a pinch.
    ///
    /// Double tap to come in, two-finger tap to go out — Apple Maps' own pair, and the reason
    /// they exist here is that a pinch needs two fingers on glass. On a laptop trackpad, in
    /// the simulator, there are none: the map could be dragged and turned but never zoomed,
    /// which is most of what a map is for. These work with one finger, a trackpad, or a mouse.
    ///
    /// Clamped by the same `CameraMath` bounds the pinch uses, so no route into the camera can
    /// put it somewhere the other route would refuse to.
    func step(_ direction: Double) {
        zoom = CameraMath.zoom(from: zoom, pinchedBy: direction > 0 ? 1.9 : 1 / 1.9)
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
        pitch = 78
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
