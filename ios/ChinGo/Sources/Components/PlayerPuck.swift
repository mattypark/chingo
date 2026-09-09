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

    /// The last direction actually travelled, in degrees. Survives standing still.
    @State private var heldHeading: Double = 0

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
    /// How tall the bear stands on screen.
    ///
    /// 44, down from 58. At the old size the player loomed over the street they were standing
    /// on -- a bear the height of the buildings beside it is a monster in a diorama rather
    /// than somebody out for a walk.
    private static let bearHeight: CGFloat = 44

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

    /// Where the bear is looking, relative to the camera.
    ///
    /// The heading is in the world and the camera turns independently, so the difference is
    /// what the eye actually sees. Nil heading holds it facing the viewer rather than snapping
    /// to north: standing still and being stared at by the back of your own bear is worse than
    /// a bear that has not committed to a direction.
    private var worldFacing: Double {
        // The way you last walked, held.
        //
        // This has been wrong twice in opposite directions. It returned zero when standing
        // still, which is "face the camera" -- so the bear turned with the view and could
        // never be walked round. Then it fell back to north, which is worse in motion: stop
        // walking east and the bear swings to face north for no reason anybody watching could
        // name.
        //
        // `course` is only published above a walking threshold, so it drops to nil every time
        // you stand still. Holding the last one means the bear stays pointed where it was
        // going, which is what a body does -- you do not rotate to true north when you stop.
        //
        // The 180 is the difference between "which way is the bear pointing in the world" and
        // "which way is it pointing on this screen". The model faces the camera at zero, and
        // the camera follows your course — so walking with the map lined up behind you left
        // the bear facing straight back at you while it walked away, which is the one pose a
        // walk cycle cannot survive. Half a turn puts its back to you when you are both going
        // the same way, and shows you its profile the moment you turn the map.
        heldHeading - cameraBearing + 180
    }

    var body: some View {
        ZStack(alignment: .top) {
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

                // The real model, turned by a real rotation.
                //
                // What was here was one front-on drawing squashed horizontally and mirrored to
                // fake a profile — which this file's own comment called a stand-in, because no
                // amount of squashing a front view puts an ear in the right place. It has one
                // now. The stranger bears on the map are still drawings: they are MapLibre
                // symbols rendered in the map's own pass, and twenty of those cost nothing
                // where twenty of these would not.
                BearScene(
                    accent: accent,
                    motion: phase == nil ? .idle : .walking,
                    facing: worldFacing
                )
                // No lift. The scene now frames the bear with its feet on the bottom edge, so
                // any offset here puts it back in the air above its own shadow.
                .frame(width: Self.bearHeight * 1.25, height: Self.bearHeight * 1.25)
            }
            .frame(width: Self.bearHeight, height: Self.bearHeight, alignment: .bottom)
            .animation(.easeOut(duration: 0.18), value: turn)

            // Above the head, not under the feet.
            //
            // Under the feet it sat between the bear and its shadow, which is the one place
            // on a map that means "on the ground" -- so the number read as a thing lying in
            // the street rather than as a label belonging to the player.
            Text("\(level)")
                .font(.custom(Typeface.bagel, size: 11))
                .foregroundStyle(accent.onSignal)
                .padding(.horizontal, 9)
                .padding(.vertical, 2)
                .background(Capsule().fill(accent.signal))
                .overlay(Capsule().stroke(Ink.groundRaised, lineWidth: 2))
                // Clear of the ears, not resting on them. The scene frames the bear with its
                // feet on the bottom edge, so its head reaches the top of that frame and a
                // badge merely "above centre" lands on the skull.
                .offset(y: -26)
        }
        .onChange(of: heading, initial: true) { _, course in
            // Only ever updated by a real course. A nil is "not walking", not "walking north".
            guard let course else { return }
            withAnimation(Motion.surface) { heldHeading = course }
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
