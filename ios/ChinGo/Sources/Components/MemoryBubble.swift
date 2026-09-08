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
                        if !memory.isDeveloped {
                            // Too small for the caption; the frame alone carries it here, and
                            // the sheet behind the pin says when.
                            Developing(developsAt: memory.developsAt, showsCaption: false)
                        } else if let image = PhotoStore.load(memory.photoFile) {
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
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Ink.text, lineWidth: 3)
                }
                .rotationEffect(.degrees(-4))
                .compositingGroup()
                .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)

                // The stem is what fixes the polaroid to a spot on the ground rather than
                // leaving it floating over the map. 3pt and solid ink: the 1.5pt translucent
                // version was a hairline next to a 3pt outline, which is the exact pairing
                // the sticker language exists to stop.
                Rectangle()
                    .fill(Ink.text)
                    .frame(width: 3, height: 14)
                Circle()
                    .fill(Ink.text)
                    .frame(width: 7, height: 7)
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
