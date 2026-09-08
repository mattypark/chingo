import SwiftUI
import ChinGoDesign

/// The bear, bottom-left, as the way into everything about you.
///
/// Draws the bear and the disc it stands on and nothing else -- no shadow, no button, no
/// badge, and no level ring. The ring used to be here and came off when the bear grew out of
/// the disc: the bear covered the arc almost completely, so it was a gauge you could not read
/// sitting on top of a character you could. The level is already a number an inch to the
/// right, and the profile banner and the map puck both still carry the real gauge.
/// `HomeBar` owns the surface it sits on and the tap that opens the profile, because a
/// button inside a button is two hit targets fighting over one thumb.
///
/// This is where the cuteness research stops being a mood board and becomes timings.
///
/// **It reacts before it acts.** The press response is a `ButtonStyle`, so it lands on the
/// touch itself rather than after the menu decides to open. Nielsen's 0.1s threshold is the
/// line where a response still feels *caused by you*; past it the character reads as inert.
/// Anthropomorphism research is harsher still — a thing that looks like it has agency and
/// then fails to respond is judged worse than a plain graphic. A cute face that does not
/// react reads as broken, not shy.
///
/// **It is never perfectly still.** A static character reads as dead, so there is always an
/// idle running.
///
/// **It does not repeat itself.** Idles are drawn from a set and never twice in a row; the
/// named mechanism of mascot fatigue is repetition without variation. This is the Clippy
/// failure, and it takes about three days to start grating.
///
/// **It looks at things.** When something is near, it leans toward *that* thing's direction
/// rather than playing a stock excited clip. Direction-specific reaction reads as noticing
/// you; a generic clip reads as decoration.
/// Squash, stretch and lean, animated together so the volume looks preserved -- as one axis
/// grows the other has to give, or the bear reads as a balloon rather than as something soft.
private struct Squish: Equatable {
    var width: Double = 1
    var height: Double = 1
    var tilt: Double = 0
}

struct MascotOrb: View {
    @Environment(\.accent) private var accent

    var level: Int
    var progress: Double
    /// Screen-relative direction of the nearest thing worth noticing, in degrees, or nil.
    var glanceTowards: Double?
    /// Days since you last met somebody. Nil when you never have.
    ///
    /// The bear is fed by the one thing this app is for, and by nothing else. There are no
    /// chores here and there should not be: inventing a second currency to keep a character
    /// happy is how an app about seeing people becomes an app about tapping a button.
    var daysSinceMeetup: Int?
    /// Outside diameter. The ring is drawn inside it.
    var diameter: CGFloat = 46

    @State private var idle: Idle = .breathe
    @State private var beat = false
    /// True while a finger is held on it.
    @State private var hugging = false
    /// Bumped per hug, to hang the haptic and the pop on.
    @State private var hugs = 0
    /// Cancelled if the finger lifts before the press becomes a press.
    @State private var holdTask: Task<Void, Never>?

    /// The idle set. Small, quiet, and deliberately more than a handful.
    ///
    /// None of these are performances — an orb 58 points across that waves its arms is a
    /// distraction sitting on top of a map. They are the difference between something alive
    /// and something printed.
    private enum Idle: CaseIterable {
        case breathe, swayLeft, swayRight, tiltLeft, tiltRight
        case bobUp, settle, perk, lean, shiver, sink, glanceUp

        /// Whether this idle is one the bear only does when it has seen somebody lately.
        ///
        /// The split is the whole of "caring for the bear", and what it deliberately is *not*
        /// is a sad bear. Finch's bird goes off on its own adventures while you are away and
        /// is pleased to see you when you get back; it never mopes, and it cannot regress.
        /// Copying the moping is how a companion becomes a debt.
        ///
        /// So a cold bear is not drooping — it is doing quieter, more inward things. Warm
        /// adds the outward ones on top: perking up, bobbing, looking around for you.
        var needsWarmth: Bool {
            switch self {
            case .perk, .bobUp, .glanceUp, .lean: true
            default: false
            }
        }

        var scale: CGFloat {
            switch self {
            case .breathe, .settle: 1.035
            case .perk, .bobUp: 1.05
            case .sink, .shiver: 0.975
            default: 1.015
            }
        }

        var rotation: Double {
            switch self {
            case .swayLeft, .tiltLeft: -3.5
            case .swayRight, .tiltRight: 3.5
            case .lean: -5
            default: 0
            }
        }

        var offset: CGFloat {
            switch self {
            case .bobUp, .perk, .glanceUp: -3
            case .sink: 2
            default: 0
            }
        }

        var duration: Double {
            switch self {
            case .shiver: 0.9
            case .perk, .bobUp: 1.6
            default: 2.6
            }
        }
    }

    /// The accent's bear, falling back to the stock artwork only if the generated set is
    /// somehow missing -- which would mean the mascot asset failed to load, and a berry bear
    /// is a better answer to that than a blank circle.
    @ViewBuilder
    private var bear: some View {
        if let image = BearIcons.all[BearIcons.name(accent: accent.id, phase: nil)] {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image("Mascot").resizable().scaledToFit()
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Ink.groundSunk)

            // The player's own bear, in the colour they picked -- not the raw berry mascot.
            // This was the last place in the app still drawing the stock artwork, which made
            // the one avatar that is definitely *you* the only one not wearing your colour.
            bear
                .frame(width: diameter * 0.94)
                // Standing out of the circle rather than sitting in it, and leaning. A face
                // cropped to a disc is a portrait; a bear whose head and ears break the edge
                // is a character standing behind a hole, which is the whole difference
                // between a logo and a mascot.
                .offset(y: -diameter * 0.20 + (beat ? idle.offset : 0))
                .rotationEffect(.degrees(-7), anchor: .bottom)
                .scaleEffect(beat ? idle.scale : 1, anchor: .bottom)
                .rotationEffect(.degrees(beat ? idle.rotation : 0), anchor: .bottom)
                // Leaning toward whatever is nearby. Capped hard: past a few degrees an
                // orb this small stops reading as "looking over there" and starts reading
                // as broken layout.
                .rotationEffect(.degrees(glanceTilt), anchor: .bottom)
                // The hug, in two parts.
                //
                // The held part: while the finger stays down the bear leans further out of
                // the disc and reaches toward it. A spring, not a ramp, so letting go throws
                // it back rather than sliding it back.
                .scaleEffect(hugging ? 1.16 : 1, anchor: .bottom)
                .rotationEffect(.degrees(hugging ? -14 : 0), anchor: .bottom)
                .offset(y: hugging ? diameter * 0.08 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hugging)
                // The pop: a squash, an overshoot and a wobble, fired once per hug.
                //
                // This is the part that stops it reading as a sliding image. Squash and
                // stretch is the oldest trick there is and it is the whole difference between
                // a drawn thing that is alive and a PNG being moved -- a character that
                // changes size without changing shape reads as a decal, because nothing soft
                // moves that way. It has to anticipate downward before it goes up, or the
                // rise has nothing to come out of.
                .keyframeAnimator(initialValue: Squish(), trigger: hugs) { view, squish in
                    view
                        .scaleEffect(x: squish.width, y: squish.height, anchor: .bottom)
                        .rotationEffect(.degrees(squish.tilt), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack(\.height) {
                        SpringKeyframe(0.86, duration: 0.10, spring: .snappy)   // anticipate
                        SpringKeyframe(1.14, duration: 0.16, spring: .bouncy)   // spring up
                        SpringKeyframe(1.0, duration: 0.34, spring: .bouncy)    // settle
                    }
                    KeyframeTrack(\.width) {
                        SpringKeyframe(1.16, duration: 0.10, spring: .snappy)   // widen as it squashes
                        SpringKeyframe(0.92, duration: 0.16, spring: .bouncy)
                        SpringKeyframe(1.0, duration: 0.34, spring: .bouncy)
                    }
                    KeyframeTrack(\.tilt) {
                        LinearKeyframe(0, duration: 0.10)
                        SpringKeyframe(-9, duration: 0.14, spring: .bouncy)
                        SpringKeyframe(4, duration: 0.16, spring: .bouncy)
                        SpringKeyframe(0, duration: 0.24, spring: .bouncy)
                    }
                }
        }
        // Deliberately not clipped and deliberately taller than it is wide. The bear stands
        // above the disc now, so clipping to the circle would cut its head off -- which is
        // exactly what the old `clipShape` on the image was doing by design.
        .frame(width: diameter, height: diameter, alignment: .center)
        .animation(Motion.surface, value: glanceTilt)
        // Long press only. Anything that reacts on touch-down eats the tap that opens the
        // profile -- which is what the first version did, so the bear animated and the
        // profile never opened.
        .onLongPressGesture(minimumDuration: 0.26, maximumDistance: 30) {
            hugs += 1
        } onPressingChanged: { pressing in
            // The lean is held only while the finger is down, and only after the press has
            // lasted long enough to be a press. `pressing` goes true immediately, so the
            // delay is explicit rather than implied.
            if pressing {
                holdTask = Task {
                    try? await Task.sleep(for: .milliseconds(260))
                    guard !Task.isCancelled else { return }
                    hugging = true
                }
            } else {
                holdTask?.cancel()
                hugging = false
            }
        }
        .feedback(.pick, on: hugs)
        .task { await liveIdly() }
        .accessibilityHidden(true)   // HomeBar labels the whole cell
    }

    private var glanceTilt: Double {
        guard let glanceTowards else { return 0 }
        // Left of you tips it left, right tips it right, and anything behind reads as nothing.
        let turn = sin(glanceTowards * .pi / 180)
        return max(-6, min(6, turn * 6))
    }

    /// Whether the bear has seen anybody lately.
    ///
    /// Three days, because that is about the point at which "yesterday" stops being a useful
    /// word for it. Never having met anybody counts as warm rather than cold: a brand-new
    /// install has not lapsed, it has not started, and greeting somebody's first launch with
    /// a subdued character is the worst possible first impression.
    private var isWarm: Bool {
        guard let daysSinceMeetup else { return true }
        return daysSinceMeetup <= 3
    }

    private func liveIdly() async {
        guard !Motion.reduceMotion else { return }
        var previous: Idle?
        while !Task.isCancelled {
            // Never the same idle twice running. One repeat is invisible; a loop of one is
            // what makes a character feel like a GIF.
            let available = Idle.allCases.filter { isWarm || !$0.needsWarmth }
            let next = available.filter { $0 != previous }.randomElement() ?? .breathe
            previous = next
            idle = next

            withAnimation(.easeInOut(duration: next.duration).repeatCount(2, autoreverses: true)) {
                beat = true
            }
            try? await Task.sleep(for: .seconds(next.duration * 2))
            beat = false
            // A pause between idles. Constant motion is as lifeless as none — living things
            // rest. A cold bear rests longer, which is the only other thing that changes: it
            // is quieter, not unhappier.
            let rest = isWarm ? 1.4...3.6 : 3.0...6.5
            try? await Task.sleep(for: .seconds(Double.random(in: rest)))
        }
    }
}
