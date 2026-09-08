import SwiftUI
import ChinGoDesign

/// First run, in two shapes.
///
/// The old version was one shape used six times: a small illustration over a paragraph over a
/// button. It worked and it read as a settings wizard, because every screen looked like the
/// last one and none of them looked like the product.
///
/// Bump's onboarding is the reference, and its whole idea is that there are exactly **two**
/// kinds of screen and they are nothing like each other:
///
/// - A **hero** is a full-bleed colour field with the character on it and four words. It
///   carries no information. Its job is to be the moment you decide you want the app.
/// - A **question** is one question, small and grey at the top, and the answer set larger than
///   anything else on screen. There is no visible field: the answer *is* the content.
///
/// The alternation is what makes it feel like a flow rather than a form. Two hero screens
/// bookend a run of questions, so the sequence has a beginning and an end rather than just
/// stopping.

// MARK: - Hero

/// A full-bleed moment. Used twice: the way in, and the way out.
///
/// Cream, like every other screen. The bear brings the only colour.
///
/// This was a full-bleed berry field for a while, on the reasoning that the logo bear is
/// purple and a hero should take over the screen. It was wrong for a simple reason: the bear
/// is *also* purple, so a purple bear on a purple field is a cut-out that has to fight its own
/// background, and the two screens it appeared on were the only two in the app that did not
/// look like the app. Bump's own splash is a colour field and every screen after it is
/// off-white -- copying the splash and not the flow got the ratio backwards.
///
/// So the field is the same paper as everything else and the hero is carried by scale instead:
/// the bear at 200 points and the headline at 42.
struct OnboardingHero<Content: View>: View {
    @Environment(\.accent) private var accent

    let headline: String
    let primary: String
    var footnote: String? = nil
    var onPrimary: () -> Void
    @ViewBuilder var art: () -> Content

    var body: some View {
        ZStack {
            Ink.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: Space.section)

                art()

                Text(headline)
                    .font(.custom(Typeface.bagel, size: 42))
                    .tracking(-1)
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-4)
                    .padding(.horizontal, Space.margin)
                    .padding(.top, Space.inset)

                Spacer(minLength: Space.section)

                Button(action: onPrimary) {
                    Text(primary)
                        .font(.custom(Typeface.bagel, size: 19))
                        .foregroundStyle(accent.onSignal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.snug)
                }
                .buttonStyle(StickerButtonStyle(fill: accent.signal, radius: Radius.pill))
                .padding(.horizontal, Space.margin)
                .padding(.trailing, Sticker.drop)

                if let footnote {
                    // Under the button, small, and legally load-bearing: this is where the
                    // terms live now. Bump does the same, and it is the honest place for
                    // them -- a whole screen that says "I agree" is a screen everybody taps
                    // through without reading, which is worse than a line they might.
                    Text(footnote)
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.textFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.section)
                        .padding(.top, Space.snug)
                }
            }
            .padding(.bottom, Space.margin)
        }
    }
}

// MARK: - Question

/// Timings the question screen needs but cannot hold itself: `OnboardingQuestion` is generic
/// over its answer, and a generic type cannot have a static stored property.
private enum Rise {
    /// How long to wait before the collapse starts.
    ///
    /// The keyboard's own dismissal is 0.25s and it animates the safe area, which moves the
    /// whole question stack. A hand-rolled offset started in the same frame fights it: the
    /// answer drops as the keyboard leaves and *then* slides up, which reads as a glitch
    /// rather than as a lift. So focus is resigned first and this waits for it to be gone.
    static let keyboardExit: Double = 0.28
}

/// One question, and the answer as the largest thing on screen.
///
/// The question is deliberately quiet -- `chinFootnote` in `textSoft`, top of the screen, no
/// heading weight. Everything the eye is meant to land on is what you typed.
///
/// The primary button is absent until there is something to submit. A permanently visible
/// "Next" that does nothing for the first few seconds teaches people to tap it twice.
struct OnboardingQuestion<Content: View>: View {
    @Environment(\.accent) private var accent

    let question: String
    let primary: String
    /// Nil while the answer is not yet valid; the button appears when it becomes non-nil.
    var canAdvance: Bool
    var footnote: String? = nil
    /// The answer has been given and is on its way out. Collapses the two gaps above it so
    /// what you typed rises into the question's place, and fades the question behind it.
    ///
    /// Only the steps with a typed answer set this. On `look`, `permissions` and `friends`
    /// there is nothing that was *yours* to lift, and lifting the controls instead would be
    /// motion for its own sake.
    var submitted: Bool = false
    var onPrimary: () -> Void
    @ViewBuilder var answer: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0).frame(height: submitted ? Space.section : Space.section * 2)

            // The question sits directly above its answer rather than being pinned to the top
            // of the screen. A question at the top and an answer in the middle are two
            // objects; a question with an answer under it is one sentence, which is the whole
            // effect this screen is after.
            Text(question)
                .font(.chinBody)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.margin)
                // Fades in place rather than collapsing its frame. The rise comes from the
                // two gaps around it, so nothing here has to be measured -- a question that
                // wraps to two lines shifts the landing by its own height and still reads
                // as the answer taking its place.
                .opacity(submitted ? 0 : 1)

            answer()
                .padding(.horizontal, Space.margin)
                .padding(.top, submitted ? Space.tight : Space.section)

            Spacer(minLength: Space.step)

            if let footnote {
                Text(footnote)
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.margin)
                    .padding(.bottom, Space.snug)
            }

            Button(action: onPrimary) {
                Text(primary)
                    .font(.custom(Typeface.bagel, size: 19))
                    // The accent decides its own label colour. Ink here would be unreadable
                    // on the darker half of the set -- pine puts it at 3.3:1.
                    .foregroundStyle(accent.onSignal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.snug)
            }
            .buttonStyle(StickerButtonStyle(fill: accent.signal, radius: Radius.pill))
            .padding(.horizontal, Space.margin)
            .padding(.trailing, Sticker.drop)
            .padding(.bottom, Space.margin)
            .opacity(canAdvance && !submitted ? 1 : 0)
            // Not just hidden -- unreachable. An invisible button that still takes taps is
            // worse than a visible one that does nothing, and during the rise it would take
            // a second tap that queues a second advance.
            .allowsHitTesting(canAdvance && !submitted)
            .animation(Motion.surface, value: canAdvance)
        }
        // One delayed animation over every value that reads `submitted`, rather than a
        // `withAnimation` at the call site: the delay is a property of this layout fighting
        // the keyboard, not of the decision to move on.
        .animation(
            Motion.reduceMotion ? nil : Motion.surface.delay(Rise.keyboardExit),
            value: submitted
        )
    }
}

/// The shared look for a typed answer: enormous, centred, and with no field around it.
struct AnswerField: View {
    @Environment(\.accent) private var accent

    var text: Binding<String>
    var placeholder: String
    var keyboard: UIKeyboardType = .default
    var limit: Int
    /// The answer has been given. Puts the keyboard away *before* the layout above starts
    /// collapsing -- see `OnboardingQuestion.keyboardExit` for why the order matters.
    var submitted: Bool = false

    @FocusState private var focused: Bool

    /// Digits only, derived from the keyboard rather than asked for separately.
    ///
    /// `.numberPad` is a suggestion, not a rule: a hardware keyboard, a paste, or a
    /// dictation all put letters into a field that asked for a number, and the age step
    /// then reads "mat" and refuses an answer nobody could see was wrong. Deriving it here
    /// means a caller cannot pick the number pad and forget the filter.
    private var digitsOnly: Bool { keyboard == .numberPad }

    var body: some View {
        TextField(placeholder, text: text)
            .font(.chinAnswer)
            .foregroundStyle(Ink.text)
            .multilineTextAlignment(.center)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)
            .tint(accent.signal)
            .lineLimit(1)
            // Shrinks rather than truncating or scrolling. A name that scrolls out of its own
            // field is the one thing this layout cannot survive, because the field is invisible
            // and there is no edge to explain where the text went.
            .minimumScaleFactor(0.45)
            .onChange(of: text.wrappedValue) { _, new in
                var cleaned = digitsOnly ? new.filter(\.isNumber) : new
                if cleaned.count > limit { cleaned = String(cleaned.prefix(limit)) }
                if cleaned != new { text.wrappedValue = cleaned }
            }
            .onAppear {
                // Keyboard up on arrival. The screen asks one question; making somebody tap
                // the answer before they can give it is a step that exists for no reason.
                //
                // Guarded on `submitted` because the delay outlives the tap: a field that
                // arrives and is answered inside 0.35s would otherwise take the keyboard
                // back up underneath the rise.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    guard !submitted else { return }
                    focused = true
                }
            }
            .onChange(of: submitted) { _, done in
                if done { focused = false }
            }
    }
}

// MARK: - Driving it from the command line

extension View {
    /// Types the answer and presses the button, from `-answer` and `-autoSubmit`.
    ///
    /// A no-op without the flags, and compiled out of release entirely. It exists because the
    /// rise is a *submit* beat: `simctl` can open this screen but cannot tap anything on it,
    /// so without a way to press the button from a launch argument the one animation the
    /// screen was built for could only ever be described, not looked at.
    func debugAnswer(
        _ text: Binding<String>,
        for step: String,
        submit: @escaping () -> Void
    ) -> some View {
        #if DEBUG
        task {
            guard let answer = DemoSeed.answer(for: step) else { return }
            // After `AnswerField`'s own focus delay, so the keyboard is up and the beat
            // starts from the state a real person would be in.
            try? await Task.sleep(for: .milliseconds(700))
            text.wrappedValue = answer

            guard DemoSeed.autoSubmits else { return }
            try? await Task.sleep(for: .milliseconds(700))
            submit()
        }
        #else
        self
        #endif
    }
}
