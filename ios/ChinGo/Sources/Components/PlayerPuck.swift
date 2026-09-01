import SwiftUI
import ChinGoDesign

/// You, on the map.
///
/// Sits dead centre and never moves — the map moves under it. That is what makes a map app
/// feel like a game rather than a navigation tool, and it is the most load-bearing decision
/// on this screen.
struct PlayerPuck: View {
    var level: Int
    var progress: Double

    @State private var breathing = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Ink.groundRaised)
                    .shadow(color: Ink.shade, radius: 14, y: 7)

                // Track first, then the earned arc on top of it, so the ring reads as a
                // gauge rather than as a decorative stroke.
                Circle()
                    .stroke(Ink.groundSunk, lineWidth: 4)
                    .padding(3)

                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(Ink.signal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)

                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Ink.textSoft)
            }
            .frame(width: 68, height: 68)

            // Sits below the ring, not across it: a badge that clips the gauge makes the
            // gauge unreadable at exactly the moment it matters.
            Text("\(level)")
                .font(.custom(Typeface.bagel, size: 12))
                .foregroundStyle(Ink.onSignal)
                .padding(.horizontal, 9)
                .padding(.vertical, 2)
                .background(Capsule().fill(Ink.signal))
                .overlay(Capsule().stroke(Ink.groundRaised, lineWidth: 2))
                .offset(y: -9)
                .shadow(color: Ink.shade, radius: 4, y: 2)
        }
        .background(alignment: .bottom) {
            // Contact shadow on the ground plane. Elliptical because the ground is raked
            // back — a round shadow under a tilted map reads as a sticker.
            Ellipse()
                .fill(Ink.text.opacity(0.10))
                .frame(width: 74, height: 20)
                .blur(radius: 5)
                .scaleEffect(breathing ? 1.06 : 0.94)
                .offset(y: 4)
        }
        .onAppear {
            guard !Motion.reduceMotion else { return }
            withAnimation(Motion.breathe) { breathing = true }
        }
        .accessibilityLabel("You, level \(level)")
    }
}
