import SwiftUI
import ChinGoDesign

/// The shape every onboarding screen takes.
///
/// One illustration, one heading, one paragraph, one button. Written as a single component so
/// the five screens cannot drift apart — onboarding that changes its own layout between steps
/// reads as five screens rather than one flow.
struct OnboardingStep<Content: View>: View {
    @Environment(\.accent) private var accent

    enum Art {
        case bearFull, bearCorner
    }

    let art: Art
    let title: String
    /// Named `message` rather than `body`, which is already taken by View.
    let message: String
    let primary: String
    var secondary: String? = nil
    var footnote: String? = nil
    var onPrimary: () -> Void
    var onSecondary: () -> Void = {}
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Space.step)

            Image(art == .bearFull ? "Mascot" : "CornerBear")
                .resizable()
                .scaledToFit()
                .frame(height: art == .bearFull ? 168 : 132)

            Text(title)
                .font(.custom(Typeface.bagel, size: 30))
                .foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
                .padding(.top, Space.inset)

            Text(message)
                .font(.chinBody)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)
                .padding(.top, Space.snug)
                .padding(.horizontal, Space.tight)

            content()
                .padding(.top, Space.inset)

            Spacer(minLength: Space.step)

            Button(action: onPrimary) {
                Text(primary)
                    .font(.custom(Typeface.bagel, size: 19))
                    .foregroundStyle(Ink.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.step)
            }
            .buttonStyle(StickerButtonStyle(fill: accent.signal, radius: Radius.surface))
            .hitTarget()

            if let secondary {
                Button(action: onSecondary) {
                    Text(secondary)
                        .font(.chinCallout)
                        .foregroundStyle(Ink.textSoft)
                        .padding(.vertical, Space.snug)
                }
                .buttonStyle(SquashButtonStyle())
                .hitTarget()
                .padding(.top, Space.tight)
            }

            if let footnote {
                Text(footnote)
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textFaint)
                    .padding(.top, Space.tight)
            }
        }
        .padding(.horizontal, Space.margin)
        .padding(.bottom, Space.margin)
        // The hard shadow on the primary button sits outside its frame and needs room.
        .padding(.trailing, Sticker.drop)
    }
}

extension OnboardingStep where Content == EmptyView {
    init(
        art: Art,
        title: String,
        message: String,
        primary: String,
        secondary: String? = nil,
        footnote: String? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void = {}
    ) {
        self.init(
            art: art,
            title: title,
            message: message,
            primary: primary,
            secondary: secondary,
            footnote: footnote,
            onPrimary: onPrimary,
            onSecondary: onSecondary,
            content: { EmptyView() }
        )
    }
}
