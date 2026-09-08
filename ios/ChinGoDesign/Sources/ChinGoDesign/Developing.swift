import SwiftUI

/// What sits where a photo will be.
///
/// Not a spinner and not a placeholder. A spinner says the app is busy; a placeholder says
/// something is missing. This says a specific photo exists, is not yours to look at yet, and
/// when it will be -- which is the difference between waiting and being stalled.
///
/// Drawn as an exposed frame: the accent bleeding through a dark ground, the way a print
/// looks held up to the light before it has come through. The one moving part is a slow
/// breathe, because a still rectangle reads as a failed image load.
public struct Developing: View {
    @Environment(\.accent) private var accent

    private let developsAt: Date?
    private let showsCaption: Bool

    @State private var breathing = false

    public init(developsAt: Date?, showsCaption: Bool = true) {
        self.developsAt = developsAt
        self.showsCaption = showsCaption
    }

    public var body: some View {
        ZStack {
            Ink.text

            // The latent image. Enough of the accent to read as a photo coming through,
            // nowhere near enough to be one.
            RadialGradient(
                colors: [accent.signalDeep.opacity(0.75), accent.signalDeep.opacity(0)],
                center: .center,
                startRadius: 2,
                endRadius: 120
            )
            .opacity(breathing ? 0.9 : 0.45)

            if !showsCaption {
                // At pin size there is no room for words, and a dark square with nothing in
                // it reads as a thumbnail that failed to load. The glyph is the whole
                // difference between "not yet" and "broken".
                Image(systemName: "hourglass")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(accent.signalLift)
            }

            if showsCaption {
                VStack(spacing: Space.hair) {
                    Text("developing")
                        .font(.custom(Typeface.bagel, size: 13))
                        .foregroundStyle(accent.signalLift)

                    if let wait = Develop.spokenWait(until: developsAt) {
                        Text(wait)
                            .font(.chinFootnote)
                            .foregroundStyle(Ink.onSignal.opacity(0.55))
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.tight)
                .minimumScaleFactor(0.7)
            }
        }
        .onAppear {
            guard !Motion.reduceMotion else { return }
            withAnimation(Motion.breathe) { breathing = true }
        }
        .accessibilityElement()
        .accessibilityLabel(
            Develop.spokenWait(until: developsAt)
                .map { "Photo developing, ready \($0)" } ?? "Photo developing"
        )
    }
}
