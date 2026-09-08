import Testing
import Foundation
@testable import ChinGoEngine

@Suite("The horizon")
struct HorizonTests {

    @Test("The default camera can actually see the horizon")
    func defaultPitchShowsHorizon() {
        // The bug this locks out: the pitch ceiling used to be 70, and at 70 the horizon is
        // above the top of the frame. So there was no camera angle the app could reach where
        // the sky band was drawing over sky rather than over map tiles.
        let top = CameraMath.pitchRange.upperBound
        #expect(CameraMath.horizonFraction(atPitch: top) != nil)
        #expect(CameraMath.horizonFraction(atPitch: 80) != nil)
    }

    @Test("Below about 72 degrees there is no horizon on screen")
    func lowPitchHasNoHorizon() {
        #expect(CameraMath.horizonFraction(atPitch: 62) == nil)
        #expect(CameraMath.horizonFraction(atPitch: 70) == nil)
    }

    @Test("The horizon comes down the screen as the camera rakes back")
    func horizonDescendsWithPitch() {
        let angles = [75.0, 78, 80, 82]
        let places = angles.compactMap { CameraMath.horizonFraction(atPitch: $0) }
        #expect(places.count == angles.count)
        #expect(places == places.sorted(), "a flatter camera must put the horizon lower, not higher")
    }

    @Test("At the opening pitch it lands about a quarter down")
    func openingPitchIsNearAQuarter() {
        // The reference sits around 25%. This is the number the sky band and the haze ramp
        // are both built on, so it is worth pinning rather than leaving to taste.
        guard let place = CameraMath.horizonFraction(atPitch: 80) else {
            Issue.record("no horizon at the opening pitch")
            return
        }
        #expect(abs(place - 0.24) < 0.02)
    }
}
