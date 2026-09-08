import SwiftUI
import ChinGoDesign

/// You, the catch, and everything else -- as one object.
///
/// What was here before was three controls pinned to three corners with the whole width of
/// the screen between them. Each was fine; together they read as three unrelated things that
/// happened to land on the same row, and the two outer ones sat so far apart that neither
/// looked like it belonged to the other.
///
/// So: one slab, three cells, hard outline, hard shadow. The same sticker the profile is
/// built from, finally on the screen people actually spend their time on.
///
/// **The catch button breaks the top edge rather than sitting inside a cell.** It is 78
/// points across, it has a halo, and its fill gauge *is* the hold countdown -- shrink it into
/// a third of a bar and the one gesture in the app worth discovering becomes invisible. So
/// it keeps its full size and stands proud of the slab, and the slab leaves it a gap. The
/// tap and the hold are untouched.
struct HomeBar: View {
    @Environment(\.accent) private var accent

    var level: Int
    var progress: Double
    /// Screen-relative direction of the nearest thing worth noticing. Drives the bear's lean.
    var glanceTowards: Double?
    var canCatch: Bool
    /// Bumped by the owner when a hold commits, so the reward beat and haptic land there.
    var catchPulse: Int

    var onProfile: () -> Void
    var onCatch: () -> Void
    var onCatchHold: () -> Void
    var onGlobe: () -> Void

    /// How far the catch button stands above the slab. Enough that it is unmistakably in
    /// front, little enough that it still reads as belonging to the bar rather than hovering
    /// over it.
    private static let lift: CGFloat = 30
    /// The hole the slab leaves for it: the 78pt button plus a little air on each side.
    private static let well: CGFloat = 94
    /// 74, not 64. At 64 the slab read as a strip with things in it rather than as an object
    /// -- the cells had no air above or below them and the rules ran almost edge to edge.
    /// The catch button's `lift` is unchanged, so it still stands the same distance proud.
    private static let height: CGFloat = 74

    var body: some View {
        slab
            .overlay(alignment: .top) {
                CatchButton(
                    enabled: canCatch,
                    action: onCatch,
                    longPress: onCatchHold
                )
                .rewardBeat(on: catchPulse)
                .feedback(.caught, on: catchPulse)
                .offset(y: -Self.lift)
            }
            // The overlay draws outside the slab, so the row above has to be told about it.
            .padding(.top, Self.lift)
            .animation(Motion.surface, value: canCatch)
    }

    private var slab: some View {
        HStack(spacing: 0) {
            meCell
            rule
            Color.clear.frame(width: Self.well)
            rule
            globeCell
        }
        .frame(height: Self.height)
        .sticker(fill: Ink.groundRaised, radius: Radius.surface)
    }

    /// 3pt, in ink, like every other line in this language. A hairline here would be a
    /// different design language sharing one object with this one.
    private var rule: some View {
        Rectangle()
            .fill(Ink.text)
            .frame(width: 3)
            .padding(.vertical, Space.snug)
    }

    /// Bottom-left is you. On a map screen that is the one position people learn without
    /// being told.
    /// Tap opens the profile; press and hold hugs the bear.
    ///
    /// Not a `Button`, and that is the fix rather than a preference. The hug used to be a
    /// simultaneous gesture on the button's own label, and a gesture attached to a label
    /// swallows the button's tap -- so the bear animated and the profile never opened, which
    /// is exactly what it looked like. A plain view with an explicit tap gesture and an
    /// explicit long press lets the two coexist, because the long press does not begin until
    /// well after a tap would have ended.
    private var meCell: some View {
        HStack(spacing: Space.tight) {
                MascotOrb(
                    level: level,
                    progress: progress,
                    glanceTowards: glanceTowards
                )
                // The level moves out of the badge that used to hang off the orb and becomes
                // a numeral beside it. A badge overhanging the bear needs room below the
                // circle, and inside a bar there is none -- it either collides with the
                // outline or gets clipped by it.
                Text("\(level)")
                    .font(.custom(Typeface.bagel, size: 17))
                    .foregroundStyle(accent.signal)
                    .contentTransition(.numericText())
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onProfile)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("You, level \(level)")
    }

    /// The planet.
    ///
    /// This slot used to be a stack-of-cards icon opening a menu of four destinations, which
    /// was one door too many: the errands on it -- add somebody, your handle, the album -- are
    /// all things you do *around* a catch, and they belong on the catch button's own menu
    /// where the thumb already is. What is left is the one thing that is genuinely a different
    /// place rather than another errand, so it stops being a menu and becomes the place.
    private var globeCell: some View {
        Button(action: onGlobe) {
            Image(systemName: "globe")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Ink.textSoft)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(SquashButtonStyle())
        .accessibilityLabel("See where your friends are")
    }
}
