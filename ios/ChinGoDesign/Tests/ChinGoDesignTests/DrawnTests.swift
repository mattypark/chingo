import Testing
@testable import ChinGoDesign

/// The order things get drawn in.
///
/// This is the one part of the effect a screenshot cannot show, and the part that is wrong if
/// anybody ever retunes the windows by eye: four beats that all happen at once is a fade, and
/// four that never overlap is a queue.
@Suite("Drawn")
struct DrawnTests {

    @Test("Nothing is drawn at zero and everything is drawn at one")
    func endsAreClean() {
        let blank = Drawn.blank
        #expect(blank.line == 0)
        #expect(blank.outline == 0)
        #expect(blank.fill == 0)
        #expect(blank.content == 0)
        #expect(blank.isBlank)

        let done = Drawn.complete
        #expect(done.line == 1)
        #expect(done.outline == 1)
        #expect(done.fill == 1)
        #expect(done.content == 1)
        #expect(!done.isBlank)
    }

    @Test("Progress outside 0 to 1 is clamped rather than extrapolated")
    func clamped() {
        #expect(Drawn(-4).progress == 0)
        #expect(Drawn(9).progress == 1)
    }

    @Test("The beats start in the order a hand would draw them")
    func theOrderIsTheDesign() {
        // The first moment each beat is under way. Line, then outline, then fill, then text --
        // if any pair of these swaps, the thing stops reading as being drawn.
        func begins(_ beat: (Drawn) -> Double) -> Double {
            stride(from: 0.0, through: 1.0, by: 0.005).first { beat(Drawn($0)) > 0 } ?? 1
        }
        let line = begins(\.line)
        let outline = begins(\.outline)
        let fill = begins(\.fill)
        let content = begins(\.content)

        #expect(line < outline)
        #expect(outline < fill)
        #expect(fill < content)
    }

    @Test("Each beat is under way before the one in front of it has finished")
    func theBeatsOverlap() {
        // Strictly sequential beats read as four separate events waiting for each other. At
        // the moment the outline finishes, the fill must already have started; same for the
        // fill and the text.
        let outlineDone = stride(from: 0.0, through: 1.0, by: 0.005).first { Drawn($0).outline >= 1 } ?? 1
        #expect(Drawn(outlineDone).fill > 0)

        let fillDone = stride(from: 0.0, through: 1.0, by: 0.005).first { Drawn($0).fill >= 1 } ?? 1
        #expect(Drawn(fillDone).content > 0)
    }

    @Test("No beat runs backwards")
    func everyBeatIsMonotonic() {
        var previous = Drawn(0)
        for step in stride(from: 0.0, through: 1.0, by: 0.01) {
            let now = Drawn(step)
            #expect(now.line >= previous.line)
            #expect(now.outline >= previous.outline)
            #expect(now.fill >= previous.fill)
            #expect(now.content >= previous.content)
            previous = now
        }
    }

    @Test("The stroke eases at both ends rather than running at one speed")
    func easedNotLinear() {
        // A stroke drawn at constant speed reads as a wipe revealing a finished line. The
        // middle of a smoothstep is ahead of the linear midpoint's neighbours on both sides.
        let quarter = Drawn.eased(0.25, from: 0, to: 1)
        let half = Drawn.eased(0.5, from: 0, to: 1)
        let threeQuarters = Drawn.eased(0.75, from: 0, to: 1)

        #expect(half == 0.5)
        #expect(quarter < 0.25)          // slow out of the gate
        #expect(threeQuarters > 0.75)    // and slowing into the corner
    }

    @Test("A window with no width still answers")
    func degenerateWindow() {
        #expect(Drawn.eased(0.4, from: 0.5, to: 0.5) == 0)
        #expect(Drawn.eased(0.6, from: 0.5, to: 0.5) == 1)
    }
}

/// A screen's worth of chrome, drawn one piece at a time.
@Suite("Drawn screen")
struct DrawnScreenTests {

    @Test("Blank and complete are blank and complete for every piece")
    func endsAreClean() {
        let blank = DrawnScreen(0, pieces: 4)
        let done = DrawnScreen(1, pieces: 4)
        for rank in 0..<4 {
            #expect(blank.piece(rank).isBlank)
            #expect(done.piece(rank).progress == 1)
        }
    }

    @Test("Each piece is behind the one in front of it")
    func piecesAreStaggered() {
        // Halfway through, the first piece must be further along than the last -- that gap is
        // the entire effect, and without it this is a fade with more code.
        let half = DrawnScreen(0.5, pieces: 4)
        let steps = (0..<4).map { half.piece($0).progress }
        for (earlier, later) in zip(steps, steps.dropFirst()) {
            #expect(earlier > later)
        }
    }

    @Test("Every piece finishes by the end, not after it")
    func nothingIsLeftHalfDrawn() {
        // A stagger that runs past 1 leaves the last piece mid-stroke at the moment the
        // screen is considered done, and whatever happens next happens over the top of it.
        let done = DrawnScreen(1, pieces: 6)
        #expect(done.piece(5).progress == 1)
    }

    @Test("One piece is the same thing as drawing one object")
    func collapsesToDrawn() {
        // With nothing to stagger against, this has to behave exactly like `Drawn` -- if it
        // does not, a single-piece screen draws on a different curve from a card.
        for step in stride(from: 0.0, through: 1.0, by: 0.1) {
            #expect(abs(DrawnScreen(step, pieces: 1).piece(0).progress - step) < 0.0001)
        }
    }

    @Test("A rank outside the screen is clamped rather than extrapolated")
    func rankIsClamped() {
        let screen = DrawnScreen(0.5, pieces: 3)
        #expect(screen.piece(-2).progress == screen.piece(0).progress)
        #expect(screen.piece(99).progress == screen.piece(2).progress)
    }

    @Test("The stagger takes up part of the gesture, not all of it")
    func spreadIsPartial() {
        // All of it and the last piece only starts as the first finishes, which is a queue.
        #expect(DrawnScreen.spread > 0)
        #expect(DrawnScreen.spread < 1)
    }
}
