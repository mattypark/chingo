import SwiftUI
import ChinGoDesign

/// The bear, bottom-left, as the way into everything about you.
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
    var action: () -> Void

    @State private var idle: Idle = .breathe
    @State private var beat = false

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

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Ink.groundRaised)
                    .elevated(.float)

                Circle()
                    .stroke(Ink.groundSunk, lineWidth: 3)
                    .padding(2)

                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(accent.signal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(2)

                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40)
                    .offset(y: 4 + (beat ? idle.offset : 0))
                    .scaleEffect(beat ? idle.scale : 1, anchor: .bottom)
                    .rotationEffect(.degrees(beat ? idle.rotation : 0), anchor: .bottom)
                    // Leaning toward whatever is nearby. Capped hard: past a few degrees an
                    // orb this small stops reading as "looking over there" and starts reading
                    // as broken layout.
                    .rotationEffect(.degrees(glanceTilt), anchor: .bottom)
                    .clipShape(Circle())

                Text("\(level)")
                    .font(.custom(Typeface.bagel, size: 11))
                    .foregroundStyle(accent.onSignal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(accent.signal))
                    .overlay(Capsule().stroke(Ink.groundRaised, lineWidth: 2))
                    .offset(y: 26)
            }
            // Tall enough to contain the badge hanging below the circle, which the stack
            // would otherwise clip and the screen edge would cut in half.
            .frame(width: 58, height: 76, alignment: .top)
        }
        .buttonStyle(SquashButtonStyle())
        .hitTarget()
        .animation(Motion.surface, value: glanceTilt)
        .task { await liveIdly() }
        .accessibilityLabel("You, level \(level)")
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
