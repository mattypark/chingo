import SwiftUI

/// Every animation in the app names a token from this file. No view invents its own
/// spring.
///
/// The research is blunt about why: Pokémon GO's own players revolted when every XP gain
/// became a blocking full-screen modal. Celebration has to scale to the size of what
/// happened, and that is only enforceable if the vocabulary is finite.
public enum Motion {

    // MARK: Interface — the boring 95%

    /// A control acknowledging a tap. Fast, almost no bounce.
    public static let tap = Animation.spring(duration: 0.22, bounce: 0.15)
    /// A sheet, a tray, a card expanding. Enough bounce to feel soft, not springy.
    public static let surface = Animation.spring(duration: 0.42, bounce: 0.22)
    /// Something arriving on the map or in the album.
    public static let arrive = Animation.spring(duration: 0.55, bounce: 0.34)
    /// Something leaving. Always faster than its arrival — exits that linger feel broken.
    public static let dismiss = Animation.spring(duration: 0.26, bounce: 0)

    // MARK: Reward — the three moments that get the whole juice budget
    //
    // Catch, level-up, memory resurface. Nothing else is allowed a reward animation.

    /// The wind-up before a payoff. Slow, and it must be short enough that nobody waits.
    public static let anticipate = Animation.spring(duration: 0.30, bounce: 0)
    /// The payoff itself. High bounce, on purpose.
    public static let impact = Animation.spring(duration: 0.50, bounce: 0.52)
    /// The settle after the payoff. Bounce drains to nothing.
    public static let settle = Animation.spring(duration: 0.70, bounce: 0.10)

    // MARK: Changing screens

    /// The gap between one piece of chrome leaving and the next one following it.
    ///
    /// A screen change that moves everything at once is the system's transition, and it reads
    /// as a page turning — one flat plane sliding over another. Staggering reads instead as
    /// the objects on this screen leaving and different ones arriving, which is what a book of
    /// stickers does when you turn it out.
    ///
    /// 0.05 rather than 0.1: at a tenth of a second per piece the last one is a third of a
    /// second behind the first, and the screen reads as slow rather than as choreographed.
    public static let stagger: Double = 0.05

    /// How long the arriving screen waits for the one it is replacing to get out of the way.
    ///
    /// Shorter than the outgoing chrome takes to finish, deliberately. Waiting for a clean
    /// hand-off reads as two separate events with a pause between them; overlapping slightly
    /// reads as one screen pushing the other out.
    public static let arrivalHold: Double = 0.16

    /// When one piece of chrome starts moving during a swap between two screens.
    ///
    /// `rank` is its place within its own screen's chrome, counted in reading order. The
    /// screen being left goes first, from zero; the screen arriving follows behind
    /// `arrivalHold`, which is what stops both screens having chrome in the air at once.
    ///
    /// Pure, so the choreography can be checked without a simulator — the one thing about a
    /// staggered transition that cannot be seen in a still.
    public static func popDelay(rank: Int, arriving: Bool) -> Double {
        (arriving ? arrivalHold : 0) + Double(max(0, rank)) * stagger
    }

    // MARK: Ambience
    //
    // Idle life on the map. Long, unsynchronised, never demanding attention.

    public static let breathe = Animation.easeInOut(duration: 2.6).repeatForever(autoreverses: true)

    /// A signal going out and not coming back. Radar, ripples, anything that leaves.
    ///
    /// Deliberately not `breathe`, and the difference is the whole point: `breathe`
    /// autoreverses, so a ring driven by it grows and then *shrinks back into the middle*,
    /// which reads as a thing inflating and deflating rather than as something being sent.
    /// Linear rather than eased for the same reason -- a pulse that slows as it travels reads
    /// as running out of energy, and this one is meant to keep going.
    public static let emit = Animation.linear(duration: 2.4).repeatForever(autoreverses: false)
    public static let drift = Animation.easeInOut(duration: 7.0).repeatForever(autoreverses: true)

    /// One guarded read of the system setting, so UIKit never leaks into a view file and
    /// the package still compiles for macOS where the engine tests run.
    ///
    /// `UIAccessibility` is main-actor isolated under Swift 6, and every caller is a view
    /// body or an `onAppear`, so the isolation is free rather than a constraint.
    @MainActor
    public static var reduceMotion: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }
}

/// The phases of a reward. Drives `PhaseAnimator` so the three-beat shape is written once
/// instead of being re-timed by hand at every call site.
public enum RewardPhase: CaseIterable {
    case rest, anticipate, impact, settle

    public var scale: CGFloat {
        switch self {
        case .rest: 1.0
        case .anticipate: 0.88   // squash: the wind-up reads as gathering
        case .impact: 1.18       // stretch: the overshoot is the payoff
        case .settle: 1.0
        }
    }

    public var animation: Animation {
        switch self {
        case .rest: Motion.settle
        case .anticipate: Motion.anticipate
        case .impact: Motion.impact
        case .settle: Motion.settle
        }
    }
}

public extension View {
    /// Squash-and-stretch on a value change, in one modifier.
    ///
    /// `trigger` is what to watch; the closure gets the current phase so a call site can
    /// layer its own colour or glow onto the same three beats.
    func rewardBeat<T: Equatable>(on trigger: T) -> some View {
        phaseAnimator(RewardPhase.allCases, trigger: trigger) { view, phase in
            view.scaleEffect(phase.scale)
        } animation: { phase in
            phase.animation
        }
    }

    /// Respect the system setting. A game is exactly the kind of app that forgets to.
    @MainActor
    func reducedMotionSafe(_ animation: Animation) -> Animation? {
        Motion.reduceMotion ? nil : animation
    }

    /// One piece of chrome popping away, and popping back.
    ///
    /// It shrinks into itself rather than sliding off an edge, because everything on these
    /// screens is a printed object stuck to the map: a sticker does not slide away, it comes
    /// off. 0.86 and not smaller — past about 0.8 the shrink starts to read as a thing falling
    /// backwards into the screen, which is a depth cue this flat language does not have.
    ///
    /// The direction is read from `hidden` at the moment it changes, so one modifier covers
    /// both halves of a swap: leaving takes `Motion.dismiss` from rank zero, arriving takes
    /// `Motion.arrive` from behind `Motion.arrivalHold`. Exits stay faster than entrances.
    @MainActor
    func pops(hidden: Bool, rank: Int) -> some View {
        scaleEffect(hidden ? 0.86 : 1)
            .opacity(hidden ? 0 : 1)
            .allowsHitTesting(!hidden)
            .animation(
                Motion.reduceMotion
                    ? nil
                    : hidden
                        ? Motion.dismiss.delay(Motion.popDelay(rank: rank, arriving: false))
                        : Motion.arrive.delay(Motion.popDelay(rank: rank, arriving: true)),
                value: hidden
            )
    }
}
