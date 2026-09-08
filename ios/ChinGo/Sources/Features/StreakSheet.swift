import SwiftUI
import SwiftData
import ChinGoDesign
import ChinGoEngine

/// What you can do about a streak, which is the only reason the app has one.
///
/// A counter you cannot act on is a scoreboard, and a scoreboard that only ever goes down is
/// the mechanic `ChinGoEngine.Streak` spends a paragraph arguing against. This screen is the
/// answer to that: it holds the count, the repairs you have left, and — when a repair would
/// actually reconnect something — one button that spends one.
///
/// **Finch is the model, and the part worth copying is not the hammer.** Finch gives you two
/// streak repairs and no way to buy more, so spending one is a decision rather than an undo.
/// But the thing every review of it independently mentions is that coming back after a lapse
/// is *greeted*. That costs nothing to build and it is most of the difference between a habit
/// app people keep and one they delete. So there is no red, no "you lost it", and no number
/// counting what you gave up — the largest thing on the screen is always what you still have.
struct StreakSheet: View {
    @Environment(\.accent) private var accent
    @Environment(\.modelContext) private var context

    let state: MapState

    @Query private var me: [MeRecord]

    /// Bumped when a repair is spent, to hang the haptic on.
    @State private var spends = 0

    private var identity: MeRecord? { me.first }
    private var freezesLeft: Int { identity?.freezesLeft ?? 0 }

    /// Whether there is a repair to offer: a gap the engine says is bridgeable, and enough
    /// left to bridge it. Both halves matter — the engine answers "would this work", the
    /// record answers "can you afford it".
    private var repair: [Int]? {
        let gap = state.repairableDays
        guard !gap.isEmpty, gap.count <= freezesLeft else { return nil }
        return gap
    }

    var body: some View {
        SheetShell {
            VStack(spacing: 0) {
                count

                Text(headline)
                    .font(.chinHand)
                    .foregroundStyle(Ink.textSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.margin)
                    .padding(.top, Space.tight)

                Spacer(minLength: Space.step)

                repairsLeft

                Spacer(minLength: Space.step)

                if let repair {
                    keepItGoing(covering: repair)
                } else {
                    Text(footnote)
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.textFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.margin)
                        .padding(.bottom, Space.margin)
                }
            }
            .padding(.horizontal, Space.margin)
        }
        // `.arrive` rather than `.levelled`. Something came back; nothing was achieved, and
        // the heavy impact is reserved for things that were.
        .feedback(.arrive, on: spends)
        .animation(Motion.surface, value: state.streakDays)
    }

    // MARK: The count

    /// The number, and nothing competing with it.
    ///
    /// Bagel, which is what this app sets numbers in, at the size the answer deserves. Zero is
    /// shown here and only here: the pill on the map hides it, but somebody who has opened
    /// this screen has asked, and answering "you have none" plainly is not the same as putting
    /// it in the corner of every screen unasked.
    private var count: some View {
        VStack(spacing: 0) {
            Text("\(state.streakDays)")
                .font(.custom(Typeface.bagel, size: 76))
                .foregroundStyle(state.streakDays > 0 ? accent.signal : Ink.textFaint)
                .contentTransition(.numericText())
                .accessibilityHidden(true)

            Text(state.streakDays == 1 ? "day" : "days")
                .chinLabelStyle()
                .foregroundStyle(Ink.textSoft)
        }
        .padding(.top, Space.section)
        .accessibilityElement()
        .accessibilityLabel(state.streakDays == 1 ? "1 day streak" : "\(state.streakDays) day streak")
    }

    /// Written by the bear, and never about what you lost.
    private var headline: String {
        if state.streakDays > 0 {
            return "You've seen somebody every day. That's the whole game."
        }
        if repair != nil {
            return "You've been busy. I kept your spot."
        }
        return "Go and meet somebody. That's all it takes to start one."
    }

    private var footnote: String {
        if state.streakDays > 0 {
            return "Meeting one person a day keeps it. Taking a photo is what counts."
        }
        return freezesLeft > 0
            ? "You've got \(freezesLeft) \(freezesLeft == 1 ? "repair" : "repairs") saved for when you need them."
            : "No repairs left, but a streak only ever takes one day to start again."
    }

    // MARK: Repairs

    /// How many are left, as objects rather than as a number.
    ///
    /// Two dots you can count at a glance beats "2 repairs remaining", and it makes the
    /// finiteness the point — you can see that there is not a third.
    private var repairsLeft: some View {
        VStack(spacing: Space.tight) {
            Text("Repairs")
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)

            HStack(spacing: Space.tight) {
                ForEach(0..<MeRecord.freezeAllowance, id: \.self) { index in
                    let spent = index >= freezesLeft

                    Image(systemName: "snowflake")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(spent ? Ink.textFaint : accent.onSignal)
                        .frame(width: 46, height: 46)
                        .sticker(
                            fill: spent ? Ink.groundSunk : accent.signal,
                            radius: Radius.control
                        )
                }
            }
            .padding(.trailing, Sticker.drop)
        }
        .accessibilityElement()
        .accessibilityLabel(
            freezesLeft == 1 ? "1 repair left" : "\(freezesLeft) repairs left"
        )
    }

    /// The one action, and it is only here when it would actually do something.
    private func keepItGoing(covering days: [Int]) -> some View {
        VStack(spacing: Space.tight) {
            Button {
                spend(on: days)
            } label: {
                Text("Keep it going")
                    .font(.custom(Typeface.bagel, size: 19))
                    .foregroundStyle(accent.onSignal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.snug)
            }
            .buttonStyle(StickerButtonStyle(fill: accent.signal, radius: Radius.pill))
            .padding(.trailing, Sticker.drop)

            // Says the cost before it is spent, not after. A finite resource that disappears
            // without having been priced is the version of this that feels like a trick.
            Text(days.count == 1
                 ? "Uses one repair to cover yesterday."
                 : "Uses \(days.count) repairs to cover the days you missed.")
                .font(.chinFootnote)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, Space.margin)
    }

    /// Spend the repairs, and let the recompute find them.
    ///
    /// The streak is not written here — `MapState` rebuilds it from the catch list and these
    /// frozen days, and `MapScreen` watches `frozenDays` for exactly this. Setting the number
    /// directly would be the stored-total drift the whole model exists to avoid.
    ///
    /// The sheet deliberately does not close afterwards. Spending a finite thing and being
    /// thrown out of the room is how you end up unsure whether it worked; staying means the
    /// count rolls up in front of you, the button goes because there is nothing left to fix,
    /// and a snowflake greys out. That sequence *is* the confirmation, and it costs one tap to
    /// leave once you have seen it.
    private func spend(on days: [Int]) {
        guard let identity, identity.freezesLeft >= days.count else { return }

        identity.frozenDays.append(contentsOf: days)
        identity.freezesLeft -= days.count
        try? context.save()
        spends += 1
    }
}
