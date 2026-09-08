import SwiftUI
import SwiftData
import ChinGoDesign
import ChinGoEngine

/// Who can see you, and who you can see — one friend at a time.
///
/// The two switches per person are the whole point. Bundling them into "share location with
/// Sam" would mean agreeing to be seen in order to see, which is the design that makes
/// location sharing feel like a toll rather than a choice. Kept apart, "I'll show you where I
/// am but I don't need to see you" is a sentence the interface can express.
///
/// Nothing here reports what the other person has chosen. `theyShareWithMe` is written by the
/// backend when they grant it, and this screen shows it as a state of *your* view rather than
/// as news about them — the difference matters when they turn it off, because "Sam stopped
/// sharing" is exactly the notification the deniability rule exists to prevent.
struct GlobeSharingSheet: View {
    @Environment(\.accent) private var accent
    @Environment(\.modelContext) private var context

    @Query(sort: \FriendRecord.metDate, order: .reverse) private var friends: [FriendRecord]
    @Query private var me: [MeRecord]

    private var identity: MeRecord? { me.first }

    var body: some View {
        SheetShell("Who can see you") {
            if friends.isEmpty {
                VStack(spacing: Space.tight) {
                    Text("No friends yet.")
                        .font(.chinBody)
                        .foregroundStyle(Ink.text)
                    Text("Catch somebody first — the globe only ever shows people you know.")
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.textSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(Space.margin)
            } else {
                ScrollView {
                    VStack(spacing: Space.snug) {
                        ForEach(friends) { friend in
                            row(friend)
                        }

                        Text("""
                            Turning someone off takes effect straight away, on both sides, \
                            and they aren't told.
                            """)
                            .font(.chinFootnote)
                            .foregroundStyle(Ink.textFaint)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.margin)
                            .padding(.top, Space.step)
                    }
                    .padding(.horizontal, Space.margin)
                }
            }
        }
    }

    private func row(_ friend: FriendRecord) -> some View {
        VStack(alignment: .leading, spacing: Space.tight) {
            HStack(spacing: Space.snug) {
                if let bear = BearIcons.all[BearIcons.name(accent: friend.accentIndex, phase: nil)] {
                    Image(uiImage: bear)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                }
                Text(friend.handle)
                    .font(.custom(Typeface.bagel, size: 18))
                    .foregroundStyle(Ink.text)
                Spacer()
            }

            Toggle(isOn: binding(for: friend, \.iShareWith)) {
                Text("They can see me")
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textSoft)
            }
            .tint(accent.signal)

            Toggle(isOn: binding(for: friend, \.theyShareWithMe)) {
                Text("I can see them")
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textSoft)
            }
            .tint(accent.signal)

            // Stated on every row rather than once at the top, because the row is where the
            // decision is made and a caveat three screens up is a caveat nobody read.
            if !GlobeSharing.canSee(
                GlobeSharing.Grant(iShare: friend.iShareWith, theyShare: friend.theyShareWithMe),
                globeEnabled: identity?.globeEnabled ?? false,
                sharingPaused: identity?.sharingPaused ?? false
            ) {
                Text(reason(for: friend))
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textFaint)
            }
        }
        .padding(Space.snug)
        .sticker(fill: Ink.groundRaised, radius: Radius.card)
        .padding(.trailing, Sticker.drop)
    }

    /// Why nobody is drawn for this friend -- but only ever about *your* settings.
    ///
    /// Never "they haven't turned you on". What the other person has or has not agreed to is
    /// not this screen's news to break, and an interface that reports it turns a private
    /// decision into something they have to explain.
    private func reason(for friend: FriendRecord) -> String {
        if identity?.globeEnabled != true { return "The globe is off." }
        if identity?.sharingPaused == true { return "You're paused." }
        if !friend.iShareWith { return "You're not sharing with them." }
        return "Not showing yet."
    }

    private func binding(
        for friend: FriendRecord,
        _ path: ReferenceWritableKeyPath<FriendRecord, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { friend[keyPath: path] },
            set: { value in
                friend[keyPath: path] = value
                try? context.save()
            }
        )
    }
}
