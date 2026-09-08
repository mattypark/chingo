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
/// **The ring is gone.** It carried the level gauge and it was the wrong place for it: a disc
/// under a standing figure reads as a plinth, and a bear on a plinth is a trophy rather than
/// somebody walking down a street. The level moved to the badge, which was already there.
/// What marks the spot now is the shadow — the same flat shadow every other bear on the map
/// stands on, which is what the ground plane actually asks for.
///
/// **It holds a heading in the world, not toward the phone.** A billboard sprite normally
/// faces the camera forever, so turning the view swings the bear round with it and the world
/// stops being a world. Instead it keeps one bearing and is drawn from whatever angle the
/// camera happens to be at: turn left and you see it in profile.
///
/// Honest about the limit. There is one drawing, front-on, so "profile" is a horizontal
/// squash and a flip rather than a side pose — the bear narrows as you come round it and
/// mirrors once you pass behind. That reads correctly at a glance and is a real technique,
/// but it is a stand-in: doing it properly needs three-quarter and side drawings, and no
/// amount of squashing a front view will produce an ear in the right place.
struct PlayerPuck: View {
    @Environment(\.accent) private var accent

    var level: Int
    /// Which step of the walk to draw, or nil to stand still. Comes from the same counter the
    /// other bears use, so the whole map bobs at one tempo.
    var phase: Int?
    /// Where the bear is facing in the world, in degrees. Nil holds it facing north.
    var heading: Double?
    /// Where the camera is looking, in degrees.
    var cameraBearing: Double

    @State private var breathing = false

    /// How tall the bear stands. Bigger than the ring on purpose: it is you, and you should be
    /// findable in a crowd of eight strangers without having to look for the ring.
    private static let bearHeight: CGFloat = 58

    /// How far round the camera is from the bear's own heading, folded to +/-180.
    private var offAxis: Double {
        let raw = (heading ?? 0) - cameraBearing
        return (raw.truncatingRemainder(dividingBy: 360) + 540)
            .truncatingRemainder(dividingBy: 360) - 180
    }

    /// Horizontal squash standing in for turning. 1 face-on, narrowest side-on.
    ///
    /// Floored well above zero on purpose. A true billboard would go to nothing at ninety
    /// degrees and the bear would vanish edge-on, which is correct for a flat card and wrong
    /// for a character -- there is always some of a bear to see.
    private var turn: CGFloat {
        let side = abs(sin(offAxis * .pi / 180))
        return 1 - 0.55 * side
    }

    /// Mirrored once the camera comes round behind it, so the lean and the light stay on the
    /// consistent side of the body as you circle.
    private var facing: CGFloat { offAxis < 0 ? -1 : 1 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // The contact shadow, flat on the ground. This is what says "standing here"
                // now that the disc has gone -- without it a bear on grass is a sticker on
                // grass.
                Ellipse()
                    .fill(Ink.text.opacity(0.22))
                    // Wider than the bear, not narrower. A shadow the same width as the body
                    // is entirely hidden by the body -- the only part of it that does any work
                    // is the part that shows past the feet.
                    .frame(width: Self.bearHeight * 0.78 * turn, height: Self.bearHeight * 0.17)
                    .offset(y: -2)

                if let bear = BearIcons.all[BearIcons.name(accent: accent.id, phase: phase)] {
                    Image(uiImage: bear)
                        .resizable()
                        .scaledToFit()
                        .frame(height: Self.bearHeight)
                        .scaleEffect(x: turn * facing, y: 1, anchor: .bottom)
                        .offset(y: -Self.bearHeight * 0.10)
                }
            }
            .frame(width: Self.bearHeight, height: Self.bearHeight, alignment: .bottom)
            .animation(.easeOut(duration: 0.18), value: turn)

            // Sits under the feet rather than across the body.
            Text("\(level)")
                .font(.custom(Typeface.bagel, size: 12))
                .foregroundStyle(accent.onSignal)
                .padding(.horizontal, 9)
                .padding(.vertical, 2)
                .background(Capsule().fill(accent.signal))
                .overlay(Capsule().stroke(Ink.groundRaised, lineWidth: 2))
                .offset(y: -4)
        }
        .scaleEffect(breathing ? 1.02 : 1, anchor: .bottom)
        .onAppear {
            guard !Motion.reduceMotion else { return }
            withAnimation(Motion.breathe) { breathing = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You, level \(level)")
    }

}
