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

    @Test("A pinch that does not move does not zoom")
    func pinchIdentity() {
        #expect(CameraMath.zoom(from: 17, pinchedBy: 1) == 17)
    }

    @Test("Zoom is logarithmic, not additive")
    func pinchIsLogarithmic() {
        // Doubling the pinch scale is exactly one zoom level, at either end of the range.
        // Adding the raw scale instead makes the map lurch at one end and crawl at the other.
        #expect(CameraMath.zoom(from: 16, pinchedBy: 2) == 17)
        #expect(CameraMath.zoom(from: 17, pinchedBy: 2) == 18)
        #expect(CameraMath.zoom(from: 17, pinchedBy: 0.5) == 16)
    }

    @Test("Zoom stays inside its range whatever the pinch")
    func zoomClamps() {
        for scale in stride(from: 0.001, through: 60.0, by: 0.37) {
            let z = CameraMath.zoom(from: CameraMath.defaultZoom, pinchedBy: scale)
            #expect(CameraMath.zoomRange.contains(z), "scale \(scale) produced \(z)")
        }
    }

    @Test("A degenerate pinch scale does not produce a broken zoom")
    func pinchGuardsZero() {
        // MagnifyGesture can report 0 on the first event of a gesture, and log2(0) is
        // -infinity, which silently poisons the camera altitude rather than crashing.
        #expect(CameraMath.zoom(from: 17, pinchedBy: 0) == 17)
        #expect(CameraMath.zoom(from: 17, pinchedBy: -3) == 17)
    }

    @Test("A city opens close enough to read the street")
    func defaultZoomIsInRange() {
        #expect(CameraMath.zoomRange.contains(CameraMath.defaultZoom))
        #expect(CameraMath.defaultZoom > 17)
    }

    @Test("Recentring turns the short way round")
    func shortestTurn() {
        #expect(CameraMath.shortestTurn(from: 359, to: 1) == 2)
        #expect(CameraMath.shortestTurn(from: 1, to: 359) == -2)
        #expect(CameraMath.shortestTurn(from: 0, to: 90) == 90)
    }
}
