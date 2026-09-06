import SwiftUI
import ChinGoDesign

/// You, on the map.
///
/// Sits dead centre and never moves — the map moves under it. That is what makes a map app
/// feel like a game rather than a navigation tool, and it is the most load-bearing decision
/// on this screen.
struct PlayerPuck: View {
    @Environment(\.accent) private var accent

    var level: Int
    var progress: Double

    @State private var breathing = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Ink.groundRaised)

                // Track first, then the earned arc on top of it, so the ring reads as a
                // gauge rather than as a decorative stroke.
                Circle()
                    .stroke(Ink.groundSunk, lineWidth: 4)
                    .padding(3)

                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(accent.signal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)

                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Ink.textSoft)
            }
            .frame(width: 68, height: 68)
            .overlay(Circle().strokeBorder(Ink.text, lineWidth: 3))
            .compositingGroup()
            .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)

            // Sits below the ring, not across it: a badge that clips the gauge makes the
            // gauge unreadable at exactly the moment it matters.
            Text("\(level)")
                .font(.custom(Typeface.bagel, size: 12))
                .foregroundStyle(accent.onSignal)
                .padding(.horizontal, 9)
                .padding(.vertical, 2)
                .background(Capsule().fill(accent.signal))
                .overlay(Capsule().stroke(Ink.groundRaised, lineWidth: 2))
                .offset(y: -9)
        }
        // The blurred contact ellipse that used to sit under this is gone. Its own comment
        // said a round shadow under a raked map "reads as a sticker" -- true, and now that
        // the whole screen is stickers, that is the thing to be rather than the thing to
        // avoid. The hard drop does the job, and it does it without blur.
        .scaleEffect(breathing ? 1.02 : 1, anchor: .bottom)
        .onAppear {
            guard !Motion.reduceMotion else { return }
            withAnimation(Motion.breathe) { breathing = true }
        }
        .accessibilityLabel("You, level \(level)")
    }
}
