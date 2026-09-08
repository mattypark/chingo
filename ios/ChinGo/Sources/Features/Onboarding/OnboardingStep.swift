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
/// Berry, not the accent. This is the mascot's own colour -- the bear in the logo is purple --
/// and it is the one place in the app allowed to take over the whole screen. The accent is the
/// player's, and at this point in the flow they have not chosen it yet; on the last screen
/// they have, and using it there would make the two heroes different colours and break the
/// bookend.
struct OnboardingHero<Content: View>: View {
    let headline: String
    let primary: String
    var footnote: String? = nil
    var onPrimary: () -> Void
    @ViewBuilder var art: () -> Content

    var body: some View {
        ZStack {
            // Not a flat fill. A single dark plum reads as a splash screen that failed to
            // load; the gradient gives it a light source and makes the bear look lit rather
            // than pasted.
            LinearGradient(
                colors: [Ink.berryDeep, Ink.berry, Ink.berryLift],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: Space.section)

                art()

                Text(headline)
                    .font(.custom(Typeface.bagel, size: 42))
                    .tracking(-1)
                    .foregroundStyle(Ink.onSignal)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-4)
                    .padding(.horizontal, Space.margin)
                    .padding(.top, Space.inset)

                Spacer(minLength: Space.section)

                Button(action: onPrimary) {
                    Text(primary)
                        .font(.custom(Typeface.bagel, size: 19))
                        .foregroundStyle(Ink.berryDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.snug)
                }
                .buttonStyle(StickerButtonStyle(fill: Ink.onSignal, radius: Radius.pill))
                .padding(.horizontal, Space.margin)
                .padding(.trailing, Sticker.drop)

                if let footnote {
                    // Under the button, small, and legally load-bearing: this is where the
                    // terms live now. Bump does the same, and it is the honest place for
                    // them -- a whole screen that says "I agree" is a screen everybody taps
                    // through without reading, which is worse than a line they might.
                    Text(footnote)
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.onSignal.opacity(0.7))
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
    var onPrimary: () -> Void
    @ViewBuilder var answer: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0).frame(height: Space.section * 2)

            // The question sits directly above its answer rather than being pinned to the top
            // of the screen. A question at the top and an answer in the middle are two
            // objects; a question with an answer under it is one sentence, which is the whole
            // effect this screen is after.
            Text(question)
                .font(.chinBody)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.margin)

            answer()
                .padding(.horizontal, Space.margin)
                .padding(.top, Space.section)

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
            .opacity(canAdvance ? 1 : 0)
            // Not just hidden -- unreachable. An invisible button that still takes taps is
            // worse than a visible one that does nothing.
            .allowsHitTesting(canAdvance)
            .animation(Motion.surface, value: canAdvance)
        }
    }
}

/// The shared look for a typed answer: enormous, centred, and with no field around it.
struct AnswerField: View {
    @Environment(\.accent) private var accent

    var text: Binding<String>
    var placeholder: String
    var keyboard: UIKeyboardType = .default
    var limit: Int

    @FocusState private var focused: Bool

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
                if new.count > limit { text.wrappedValue = String(new.prefix(limit)) }
            }
            .onAppear {
                // Keyboard up on arrival. The screen asks one question; making somebody tap
                // the answer before they can give it is a step that exists for no reason.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
            }
    }
}
