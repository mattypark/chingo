import SwiftUI
import ChinGoDesign

/// The opening.
///
/// Apple's HIG is explicit that a launch screen "isn't an onboarding experience or a splash
/// screen" and "isn't a branding opportunity," and that it should be nearly identical to the
/// first screen or it produces a visible flash. So the branding cannot live in the launch
/// screen file.
///
/// The way Instagram and TikTok legitimately do it, and what happens here:
///
///   1. The static launch screen is a plain field of `LaunchBackground` — nothing else.
///   2. This view's first frame is that same plain field, because the bear starts entirely
///      below the bottom edge. The handoff is invisible: at the moment it happens, nothing
///      on screen changes.
///   3. Only then does anything animate — the bear rises into frame, holds, and the ground
///      lifts away to reveal the map underneath.
///
/// The bear peeks up from the bottom rather than sitting centred like a logo. A centred mark
/// is a company introducing itself; something leaning into frame is a character saying hello,
/// which is the difference this app is trading on.
struct SplashView: View {
    /// Called once the ground has lifted and the map should own the screen.
    var onFinished: () -> Void

    @State private var phase: Phase = .waiting

    private enum Phase {
        case waiting, arrived, leaving
    }

    var body: some View {
        ZStack {
            Ink.ground
                .ignoresSafeArea()

            VStack {
                Spacer()
                Image("CornerBear")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260)
                    // Cropped by the bottom edge on purpose: the bear is leaning in from
                    // off-screen, not standing on the floor of the screen.
                    .offset(y: bearOffset)
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        }
        .opacity(phase == .leaving ? 0 : 1)
        // The ground lifts rather than cuts, so the map is briefly visible arriving beneath
        // it. A hard cut here reads as the app restarting.
        .scaleEffect(phase == .leaving ? 1.06 : 1)
        .task { await run() }
    }

    private var bearOffset: CGFloat {
        switch phase {
        case .waiting: 300     // fully below the edge — the frame is plain ground
        case .arrived: 70      // leaning in, bottom third cropped away
        case .leaving: 40      // a last nudge up as the ground lifts
        }
    }

    private func run() async {
        // Reduce Motion gets no animation at all, not a faster one. Someone who asked the
        // system to stop moving things did not ask for a brisker version.
        guard !Motion.reduceMotion else {
            onFinished()
            return
        }

        withAnimation(Motion.impact) { phase = .arrived }
        try? await Task.sleep(for: .milliseconds(1_000))
        withAnimation(Motion.dismiss) { phase = .leaving }
        try? await Task.sleep(for: .milliseconds(280))
        onFinished()
    }
}
