import SwiftUI
import ChinGoDesign

/// A memory, sitting on the map where it happened.
///
/// Drawn as a small polaroid rather than a pin: a pin says "a place", and this says "a day".
struct MemoryBubble: View {
    let memory: MemoryRecord
    /// How far the spot it belongs to sits from the middle of the polaroid, once the polaroid
    /// has been nudged out from under the nearby rail. The stem follows the spot; the card
    /// does not -- the same arrangement `RevealCard` uses to stay clear of the screen edge.
    var stemOffset: CGFloat = 0
    let action: () -> Void

    /// Outside width, so the caller can nudge one without guessing.
    static let width: CGFloat = 48

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
                // Leans toward the spot when the polaroid has been moved off it, so the line
                // still lands on the ground rather than hanging straight down beside it.
                Path { path in
                    path.move(to: CGPoint(x: 1.5, y: 0))
                    path.addLine(to: CGPoint(x: 1.5 + stemOffset, y: 14))
                }
                .stroke(Ink.text, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 3, height: 14)
                Circle()
                    .fill(Ink.text)
                    .frame(width: 7, height: 7)
                    .offset(x: stemOffset)
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
