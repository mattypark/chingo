import SwiftUI
import ChinGoDesign

/// You, on the map.
///
/// Sits dead centre and never moves — the map moves under it. That is what makes a map app
/// feel like a game rather than a navigation tool, and it is the most load-bearing decision
/// on this screen.
///
/// **You are a bear, like everybody else.** This used to be a grey `person.fill` silhouette
/// inside a disc, which meant the one person on the map who had actually chosen a colour was
/// the only one not wearing it — every stranger nearby stood there as their own bear while
/// the player was a placeholder glyph. The bear now stands on the ring in the accent the
/// player picked at onboarding, and changing that colour in settings changes the bear.
///
/// **The ring stayed, and became the ground.** It carries the level gauge, which is real
/// information and had nowhere else to go, and a disc under a standing figure is also what
/// says "this is where you are" on a raked camera — the same job the flat shadow does under
/// every other bear. Putting the bear *inside* the disc instead would have re-drawn the
/// player as a portrait when everyone else is a body standing on the street.
struct PlayerPuck: View {
    @Environment(\.accent) private var accent

    var level: Int
    var progress: Double
    /// Which step of the walk to draw, or nil to stand still. Comes from the same counter the
    /// other bears use, so the whole map bobs at one tempo.
    var phase: Int?

    @State private var breathing = false

    /// The disc the bear stands on. Also the gauge, so this is sized by what has to be legible
    /// in it rather than by what looks right under a bear.
    private static let ring: CGFloat = 62
    /// How tall the bear stands. Bigger than the ring on purpose: it is you, and you should be
    /// findable in a crowd of eight strangers without having to look for the ring.
    private static let bearHeight: CGFloat = 58

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                gauge

                if let bear = BearIcons.all[BearIcons.name(accent: accent.id, phase: phase)] {
                    Image(uiImage: bear)
                        .resizable()
                        .scaledToFit()
                        .frame(height: Self.bearHeight)
                        // Feet just inside the front of the disc rather than at its centre.
                        // Standing on the middle of an ellipse read as hovering over a hole.
                        .offset(y: -Self.ring * 0.28)
                }
            }
            // Room for the bear to stand above the disc without the stack clipping it.
            .frame(width: Self.ring, height: Self.ring + Self.bearHeight * 0.62, alignment: .bottom)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You, level \(level)")
    }

    private var gauge: some View {
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
        }
        .frame(width: Self.ring, height: Self.ring)
        .overlay(Circle().strokeBorder(Ink.text, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)
    }
}
