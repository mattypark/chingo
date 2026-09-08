import Foundation

/// The arithmetic behind looking around.
///
/// Pure, and therefore testable without a simulator — which matters because the failure modes
/// here are silent: a bearing that drifts negative still renders, it just puts the compass
/// needle in the wrong place, and a pitch allowed past its limit renders a horizon with no
/// tiles beyond it.
public enum CameraMath {

    /// A full swipe across the screen turns most of the way around; horizontal is about twice
    /// as sensitive as vertical because looking around is the common gesture and changing
    /// height is the rare one.
    public static let degreesPerHorizontalPoint: Double = 0.42
    public static let degreesPerVerticalPoint: Double = 0.20

    /// Straight down reads as a floor plan. The upper end used to be 70 because "past ~70 the
    /// horizon comes into view and the tiles run out behind it" -- which was true, and was
    /// exactly backwards as a reason to stop there.
    ///
    /// The horizon coming into view is the point. What lies beyond it is not missing tiles,
    /// it is sky, and `SkyBand` has been drawing sky since before this range was written. The
    /// old ceiling meant the horizon was *never* on screen at any pitch the camera could
    /// reach, so the sky band was painting a hardcoded fraction of the screen over live map
    /// tiles -- which is why the sun and the clouds have never sat right on anything.
    public static let pitchRange: ClosedRange<Double> = 25...82

    /// MapLibre's default vertical field of view, in degrees.
    ///
    /// Not a guess and not tunable from here -- it is the renderer's own constant (0.6435
    /// radians), and every horizon calculation below is only true because it matches.
    public static let verticalFieldOfView: Double = 36.87

    /// Where the horizon falls, as a fraction of screen height from the top.
    ///
    /// Returns nil when it is off the top of the frame, which is the honest answer for any
    /// pitch below about 72 and is what the old camera did at every angle it allowed.
    ///
    /// The geometry: pitch is measured from straight down, so the horizon sits `90 - pitch`
    /// degrees above the camera's axis. Divide that by the half-angle of the view and you have
    /// how far up the frame it lands, in half-heights from the centre.
    public static func horizonFraction(atPitch pitch: Double) -> Double? {
        let aboveAxis = 90 - pitch
        guard aboveAxis > 0 else { return 0 }

        let halfAngle = verticalFieldOfView / 2 * .pi / 180
        let offset = tan(aboveAxis * .pi / 180) / tan(halfAngle)
        guard offset < 1 else { return nil }

        return 0.5 - offset * 0.5
    }

    /// Below 15.5 the buildings stop extruding and the city becomes a road diagram. 20 is
    /// where Pokémon GO sits. It overzooms the z14 tiles 64×, which is why this used to stop
    /// at 19 — but the client now clamps building height up close and draws roads 1.75× wide,
    /// and between them the overzoom is what a toy diorama looks like rather than a mistake.
    public static let zoomRange: ClosedRange<Double> = 15.5...20

    /// Where a city opens. Close enough that the street you are standing on is the subject.
    public static let defaultZoom: Double = 17.2

    /// Fold any angle into 0..<360.
    public static func normalizedBearing(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// Bearing after dragging `dx` points horizontally from `origin`.
    ///
    /// Drag right, turn right. The other mapping — drag right, world turns right, so the
    /// camera turns left — is what a map-grabbing gesture does, and it is what this used to
    /// do. It reads as backwards here because the player is pinned to the centre: you are not
    /// pushing the ground around, you are turning on the spot.
    public static func bearing(from origin: Double, draggedBy dx: Double) -> Double {
        normalizedBearing(origin + dx * degreesPerHorizontalPoint)
    }

    /// Pitch after dragging `dy` points vertically from `origin`, clamped.
    public static func pitch(from origin: Double, draggedBy dy: Double) -> Double {
        min(max(origin + dy * degreesPerVerticalPoint, pitchRange.lowerBound), pitchRange.upperBound)
    }

    /// Zoom after a pinch of `scale` from `origin`.
    ///
    /// Zoom levels are logarithmic: each whole step doubles the scale. So a pinch multiplies
    /// rather than adds, and the conversion is log2. Adding the raw scale instead — the
    /// obvious-looking mistake — makes the map lurch at one end of the range and barely move
    /// at the other.
    public static func zoom(from origin: Double, pinchedBy scale: Double) -> Double {
        guard scale > 0 else { return origin }
        return min(max(origin + log2(scale), zoomRange.lowerBound), zoomRange.upperBound)
    }

    /// Shortest signed turn from one bearing to another, in −180...180.
    ///
    /// Used to decide whether the view is meaningfully off north, and to turn the short way
    /// round when recentring — without this, going from 359° to 1° spins the whole world.
    public static func shortestTurn(from: Double, to: Double) -> Double {
        let delta = normalizedBearing(to - from)
        return delta > 180 ? delta - 360 : delta
    }
}
