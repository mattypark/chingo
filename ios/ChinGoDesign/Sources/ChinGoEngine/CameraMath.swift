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

    /// Straight down reads as a floor plan and loses the buildings; past ~70 the horizon
    /// comes into view and the tiles run out behind it.
    public static let pitchRange: ClosedRange<Double> = 25...70

    /// Below 15.5 the buildings stop extruding and the city becomes a road diagram; above 19
    /// the z14 tiles are being overzoomed far enough that it stops looking deliberate.
    public static let zoomRange: ClosedRange<Double> = 15.5...19

    /// Where a city opens. Close enough that the street you are standing on is the subject.
    public static let defaultZoom: Double = 17.2

    /// Fold any angle into 0..<360.
    public static func normalizedBearing(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// Bearing after dragging `dx` points horizontally from `origin`.
    ///
    /// Dragging right turns the world right, which means turning the camera left. The
    /// opposite mapping feels like dragging a scrollbar rather than turning your head.
    public static func bearing(from origin: Double, draggedBy dx: Double) -> Double {
        normalizedBearing(origin - dx * degreesPerHorizontalPoint)
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
