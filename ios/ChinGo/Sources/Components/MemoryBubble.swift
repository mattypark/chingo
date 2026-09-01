import SwiftUI
import ChinGoDesign

/// A memory, sitting on the map where it happened.
///
/// This is the half of the product that has no equivalent in any incumbent. It is drawn as
/// a small polaroid rather than a pin because a pin says "a place" and this says "a day".
struct MemoryBubble: View {
    let pin: MemoryPin
    let action: () -> Void

    @State private var bob = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Ink.groundRaised)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Ink.groundSunk)
                        .padding(4)
                        .padding(.bottom, 9)
                    Image(systemName: "photo.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Ink.textFaint)
                        .offset(y: -3)
                }
                .frame(width: 48, height: 54)
                .rotationEffect(.degrees(-4))
                .shadow(color: Ink.shade, radius: 8, y: 4)

                // The stem is what fixes the polaroid to a spot on the ground rather than
                // leaving it floating over the map.
                Rectangle()
                    .fill(Ink.text.opacity(0.18))
                    .frame(width: 1.5, height: 14)
                Circle()
                    .fill(Ink.text.opacity(0.18))
                    .frame(width: 5, height: 5)
            }
            .offset(y: bob ? -3 : 0)
        }
        .buttonStyle(SquashButtonStyle())
        .onAppear {
            guard !Motion.reduceMotion else { return }
            withAnimation(Motion.drift.delay(Double.random(in: 0...1.4))) { bob = true }
        }
        .accessibilityLabel("Memory with \(pin.friendHandle) at \(pin.place), \(pin.agoDescription)")
    }
}
