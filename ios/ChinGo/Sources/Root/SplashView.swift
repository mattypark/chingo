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
///   2. This view's first frame is that same plain field. The handoff is invisible because
///      at the moment it happens, nothing changes.
///   3. Only *then* does anything animate: the mascot arrives, holds, and the ground lifts
///      away to reveal the map underneath.
///
/// Total is a shade over a second. Long enough to register as an opening, short enough that
/// nobody waits for it — a splash people notice the length of is a splash that is too long.
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

            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 148)
                .scaleEffect(mascotScale)
                .opacity(mascotOpacity)
                .accessibilityHidden(true)
        }
        .opacity(phase == .leaving ? 0 : 1)
        // The ground lifts rather than cuts, so the map is briefly visible arriving beneath
        // it. A hard cut here reads as the app restarting.
        .scaleEffect(phase == .leaving ? 1.08 : 1)
        .task { await run() }
    }

    private var mascotScale: CGFloat {
        switch phase {
        case .waiting: 0.82
        case .arrived: 1
        case .leaving: 1.04
        }
    }

    private var mascotOpacity: Double {
        phase == .waiting ? 0 : 1
    }

    private func run() async {
        // Reduce Motion gets no animation at all, not a faster one. A person who has asked
        // the system to stop moving things has not asked for a brisker version.
        guard !Motion.reduceMotion else {
            onFinished()
            return
        }

        withAnimation(Motion.impact) { phase = .arrived }
        try? await Task.sleep(for: .milliseconds(1_050))
        withAnimation(Motion.dismiss) { phase = .leaving }
        try? await Task.sleep(for: .milliseconds(280))
        onFinished()
    }
}
