import SwiftUI
import ChinGoDesign

/// A memory, sitting on the map where it happened.
///
/// Drawn as a small polaroid rather than a pin: a pin says "a place", and this says "a day".
struct MemoryBubble: View {
    let memory: MemoryRecord
    let action: () -> Void

    @State private var bob = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Ink.groundRaised)

                    Group {
                        if let image = PhotoStore.load(memory.photoFile) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Ink.groundSunk.overlay {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Ink.textFaint)
                            }
                        }
                    }
                    .frame(width: 40, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .offset(y: -4)
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
        .accessibilityLabel(
            "Memory with \(memory.friendHandle) at \(memory.placeLabel), \(memory.agoDescription)"
        )
    }
}
