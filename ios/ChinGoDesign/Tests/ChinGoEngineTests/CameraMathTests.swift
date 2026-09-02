import Testing
@testable import ChinGoEngine

@Suite("Camera math")
struct CameraMathTests {

    @Test("Bearings always land in 0..<360")
    func bearingsWrap() {
        for raw in stride(from: -1_080.0, through: 1_080.0, by: 7.0) {
            let b = CameraMath.normalizedBearing(raw)
            #expect(b >= 0 && b < 360, "\(raw) normalised to \(b)")
        }
    }

    @Test("Dragging right turns the camera left")
    func dragDirection() {
        // Thumb moves right, the world should follow the thumb, so the camera turns the
        // other way. Getting this backwards is the single most common feel bug in a map.
        let turned = CameraMath.bearing(from: 90, draggedBy: 100)
        #expect(turned < 90)

        let back = CameraMath.bearing(from: 90, draggedBy: -100)
        #expect(back > 90)
    }

    @Test("A full swipe turns you a long way, but not absurdly")
    func dragMagnitude() {
        // ~390pt is a phone's width. It should turn you most of the way around.
        let turn = 390 * CameraMath.degreesPerHorizontalPoint
        #expect(turn > 120 && turn < 200)
    }

    @Test("Dragging past the wrap point does not jump")
    func dragAcrossZero() {
        // Turning left from 10° should end up near 350°, not at −40°.
        let b = CameraMath.bearing(from: 10, draggedBy: 100)
        #expect(b > 300 && b < 360)
    }

    @Test("Pitch stays inside its range whatever the drag")
    func pitchClamps() {
        for dy in stride(from: -4_000.0, through: 4_000.0, by: 31.0) {
            let p = CameraMath.pitch(from: 58, draggedBy: dy)
            #expect(CameraMath.pitchRange.contains(p))
        }
    }

    @Test("Recentring turns the short way round")
    func shortestTurn() {
        #expect(CameraMath.shortestTurn(from: 359, to: 1) == 2)
        #expect(CameraMath.shortestTurn(from: 1, to: 359) == -2)
        #expect(CameraMath.shortestTurn(from: 0, to: 90) == 90)
    }
}
