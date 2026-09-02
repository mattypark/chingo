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

    /// Shortest signed turn from one bearing to another, in −180...180.
    ///
    /// Used to decide whether the view is meaningfully off north, and to turn the short way
    /// round when recentring — without this, going from 359° to 1° spins the whole world.
    public static func shortestTurn(from: Double, to: Double) -> Double {
        let delta = normalizedBearing(to - from)
        return delta > 180 ? delta - 360 : delta
    }
}
