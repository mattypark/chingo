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
struct MascotOrb: View {
    @Environment(\.accent) private var accent

    var level: Int
    var progress: Double
    /// Screen-relative direction of the nearest thing worth noticing, in degrees, or nil.
    var glanceTowards: Double?
    /// Outside diameter. The ring is drawn inside it.
    var diameter: CGFloat = 46

    @State private var idle: Idle = .breathe
    @State private var beat = false
    /// True while a finger is held on it.
    @State private var hugging = false
    /// Bumped per hug, to hang the haptic on.
    @State private var hugs = 0

    /// The idle set. Small, quiet, and deliberately more than a handful.
    ///
    /// None of these are performances — an orb 58 points across that waves its arms is a
    /// distraction sitting on top of a map. They are the difference between something alive
    /// and something printed.
    private enum Idle: CaseIterable {
        case breathe, swayLeft, swayRight, tiltLeft, tiltRight
        case bobUp, settle, perk, lean, shiver, sink, glanceUp

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
                // The hug. Held down, the bear leans further out of the disc, grows, and
                // comes down toward the thumb that is holding it.
                //
                // Honest about what this is: one front-facing sprite cannot actually wrap
                // around a finger, so this is a lean and a reach rather than a real hug pose.
                // Doing it properly needs a second drawing, and a squashed front view
                // pretending to be arms would look worse than not trying.
                .scaleEffect(hugging ? 1.22 : 1, anchor: .bottom)
                .rotationEffect(.degrees(hugging ? -13 : 0), anchor: .bottom)
                .offset(y: hugging ? diameter * 0.10 : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.55), value: hugging)
        }
        // Deliberately not clipped and deliberately taller than it is wide. The bear stands
        // above the disc now, so clipping to the circle would cut its head off -- which is
        // exactly what the old `clipShape` on the image was doing by design.
        .frame(width: diameter, height: diameter, alignment: .center)
        .animation(Motion.surface, value: glanceTilt)
        // Simultaneous, so the tap that opens the profile still works. A long press that
        // stole the gesture would mean the bear could be hugged or tapped but not both, and
        // the tap is the one that does something.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !hugging else { return }
                    hugging = true
                    hugs += 1
                }
                .onEnded { _ in hugging = false }
        )
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

    private func liveIdly() async {
        guard !Motion.reduceMotion else { return }
        var previous: Idle?
        while !Task.isCancelled {
            // Never the same idle twice running. One repeat is invisible; a loop of one is
            // what makes a character feel like a GIF.
            let next = Idle.allCases.filter { $0 != previous }.randomElement() ?? .breathe
            previous = next
            idle = next

            withAnimation(.easeInOut(duration: next.duration).repeatCount(2, autoreverses: true)) {
                beat = true
            }
            try? await Task.sleep(for: .seconds(next.duration * 2))
            beat = false
            // A pause between idles. Constant motion is as lifeless as none — living things
            // rest.
            try? await Task.sleep(for: .seconds(Double.random(in: 1.4...3.6)))
        }
    }
}
