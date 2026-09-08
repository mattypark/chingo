import Testing
@testable import ChinGoDesign

/// The staggered screen swap, checked as arithmetic.
///
/// This is the one thing about a transition that a screenshot cannot show: whether the two
/// screens ever have chrome in the air at the same time, and whether the pieces really are
/// ordered rather than all landing together with a shared animation.
@Suite("Chrome popping between screens")
struct MotionTests {

    @Test("The first thing to leave leaves immediately")
    func leadingPieceHasNoDelay() {
        #expect(Motion.popDelay(rank: 0, arriving: false) == 0)
    }

    @Test("Each piece follows the one before it by one stagger")
    func piecesAreOrdered() {
        let ranks = (0..<4).map { Motion.popDelay(rank: $0, arriving: false) }
        for (earlier, later) in zip(ranks, ranks.dropFirst()) {
            // Compared with a tolerance rather than exactly: these are sums of a binary
            // fraction, and 0.05 three times over is 0.15000000000000002.
            #expect(abs((later - earlier) - Motion.stagger) < 0.0001)
        }
    }

    @Test("Nothing arrives before the screen it replaces has started leaving")
    func arrivalWaitsForTheDeparture() {
        #expect(Motion.popDelay(rank: 0, arriving: true) > Motion.popDelay(rank: 0, arriving: false))
        // The last thing out still moves before the first thing in.
        #expect(Motion.popDelay(rank: 2, arriving: false) < Motion.popDelay(rank: 0, arriving: true))
    }

    @Test("The two screens overlap rather than queueing")
    func arrivalOverlapsTheExit() {
        // A clean hand-off -- arrival starting only once the exit has fully finished -- reads
        // as two events with a pause between them. `arrivalHold` is deliberately shorter than
        // the exit it follows.
        #expect(Motion.arrivalHold < 0.26)
        #expect(Motion.arrivalHold > Motion.stagger)
    }

    @Test("A negative rank cannot pull a piece in front of the leader")
    func rankIsClamped() {
        #expect(Motion.popDelay(rank: -3, arriving: false) == 0)
    }

    @Test("The whole swap stays inside half a second")
    func theSwapIsShort() {
        // Five pieces of chrome across two screens. Past about half a second a transition
        // stops reading as choreography and starts reading as waiting.
        #expect(Motion.popDelay(rank: 1, arriving: true) + 0.26 < 0.5)
    }
}
