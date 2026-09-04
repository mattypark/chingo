import SwiftUI
import SwiftData
import ChinGoDesign
import ChinGoEngine

/// You, your people, and your photos.
///
/// Rails rather than a grid. A grid says "here is your data"; a rail says "here is some of
/// it, there is more that way" — and on a page about people you have met, implying more is
/// closer to the truth than showing a wall.
///
/// Nothing here is a number for its own sake. Every count is something that happened.
struct ProfileScreen: View {
    let state: MapState

    @Query(sort: \FriendRecord.metDate, order: .reverse) private var friends: [FriendRecord]
    @Query(sort: \CatchRecord.happenedAt, order: .reverse) private var catches: [CatchRecord]
    @Query private var memories: [MemoryRecord]
    @Query private var me: [MeRecord]

    @Environment(\.modelContext) private var context
    @State private var selected: FriendRecord?
    @State private var editing = false

    private var identity: MeRecord? { me.first }

    private var withPhotos: [CatchRecord] {
        catches.filter { $0.photoFile != nil }
    }

    private var places: [String] {
        // Ordered by how often you have been there, so the place you actually live comes
        // first rather than whichever city sorts alphabetically.
        let counted = Dictionary(grouping: catches.compactMap(\.placeLabel), by: { $0 })
            .mapValues(\.count)
        return counted.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }

    var body: some View {
        SheetShell {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    banner
                    identityBlock
                    stats
                    peopleRail
                    photoRail
                    placeChips
                }
                .padding(.bottom, Space.step)
            }
            // The banner runs to the very top of the screen, under the status bar, the way a
            // profile page is supposed to. Insetting it would leave a strip of ground above
            // the artwork and turn a header into a card.
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $editing) {
            IdentityEditor(record: identity ?? newIdentity())
                .presentationDetents([.height(420)])
                .presentationBackground(Ink.ground)
                .presentationCornerRadius(Radius.surface)
        }
        .sheet(item: $selected) { friend in
            SheetShell(friend.handle) {
                CardDetail(friend: friend)
            }
            .presentationBackground(Ink.ground)
            .presentationCornerRadius(Radius.surface)
        }
    }

    // MARK: Banner and identity

    /// The banner, with the bear sitting on its lower edge.
    ///
    /// A flat field of the mascot's own colour rather than a photograph. A photo banner on a
    /// profile with four friends in it is an empty frame asking to be filled; a colour is
    /// finished the moment the account exists.
    private var banner: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Ink.berryDeep, Ink.berry],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 190)

            ZStack {
                Circle()
                    .fill(Ink.ground)
                Circle()
                    .strokeBorder(Ink.text, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0.02, state.levelProgress))
                    .stroke(Ink.signal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(6)
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58)
                    .offset(y: 4)
            }
            .frame(width: 104, height: 104)
            .compositingGroup()
            .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)
            // Straddling the edge is what makes it a profile rather than a card with a
            // coloured lid.
            .offset(y: 46)
        }
        .padding(.bottom, 46)
    }

    private var identityBlock: some View {
        VStack(spacing: Space.tight) {
            Text(identity?.handle.isEmpty == false ? identity!.handle : "you")
                .font(.custom(Typeface.bagel, size: 34))
                .foregroundStyle(Ink.text)
                .tracking(-0.6)

            Text("Level \(state.level) · \(state.xp) XP")
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)

            Group {
                if let bio = identity?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.chinHand)
                        .foregroundStyle(Ink.textSoft)
                } else {
                    // Not a blank line. An empty bio should ask for something, in the voice
                    // the rest of the app uses.
                    Text("Say what you're into.")
                        .font(.chinHand)
                        .foregroundStyle(Ink.textFaint)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, Space.hair)

            Button { editing = true } label: {
                Text(identity?.bio.isEmpty == false ? "Edit" : "Add yours")
                    .font(.custom(Typeface.bagel, size: 15))
                    .foregroundStyle(Ink.text)
                    .padding(.horizontal, Space.inset)
                    .padding(.vertical, Space.tight)
            }
            .buttonStyle(StickerButtonStyle(fill: Ink.signal, radius: Radius.surface))
            .hitTarget()
            .padding(.top, Space.snug)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.margin)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("\(catches.filter { $0.kind == "snap" }.count)", "meetups")
            Divider().frame(height: 28)
            stat("\(friends.count)", friends.count == 1 ? "person" : "people")
            Divider().frame(height: 28)
            stat("\(state.streakWeeks)", state.streakWeeks == 1 ? "week" : "weeks")
        }
        .padding(.vertical, Space.step)
        .sticker(fill: Ink.groundRaised)
        .padding(.horizontal, Space.margin)
        // The hard shadow sits outside the block, so the row needs room for it or it clips
        // against whatever comes next.
        .padding(.bottom, Sticker.drop)
    }

    private func newIdentity() -> MeRecord {
        let record = MeRecord()
        context.insert(record)
        return record
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.custom(Typeface.bagel, size: 26))
                .foregroundStyle(Ink.text)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Rails

    private var peopleRail: some View {
        rail("Your people", isEmpty: friends.isEmpty, emptyLine: "Nobody yet. Catch someone.") {
            ForEach(friends.sorted { $0.tier > $1.tier }) { friend in
                Button { selected = friend } label: {
                    CardView(face: friend.face, width: 132)
                }
                .buttonStyle(SquashButtonStyle())
            }
        }
    }

    private var photoRail: some View {
        rail(
            "Your photos",
            isEmpty: withPhotos.isEmpty,
            emptyLine: "Photos you take together show up here."
        ) {
            ForEach(withPhotos) { record in
                VStack(alignment: .leading, spacing: Space.hair) {
                    Group {
                        if let image = PhotoStore.load(record.photoFile) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Ink.groundSunk
                        }
                    }
                    .frame(width: 118, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .sticker(fill: .clear)

                    Text(record.friend?.handle ?? "someone")
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.textSoft)
                        .lineLimit(1)
                }
            }
        }
    }

    private var placeChips: some View {
        rail("Places", isEmpty: places.isEmpty, emptyLine: "Everywhere you meet someone.") {
            ForEach(places, id: \.self) { place in
                Text(place)
                    .font(.custom(Typeface.bagel, size: 15))
                    .foregroundStyle(Ink.text)
                    .padding(.horizontal, Space.step)
                    .padding(.vertical, Space.tight)
                    .sticker(fill: Ink.groundRaised, radius: Radius.surface)
            }
        }
    }

    /// One rail: a heading, then either its contents or a line from the bear.
    ///
    /// The empty state is a sentence, not a blank row. An empty rail with nothing in it is
    /// the moment an app is most obviously a database with no rows.
    @ViewBuilder
    private func rail<Content: View>(
        _ heading: String,
        isEmpty: Bool,
        emptyLine: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text(heading)
                .font(.custom(Typeface.bagel, size: 20))
                .foregroundStyle(Ink.text)
                .padding(.horizontal, Space.margin)

            if isEmpty {
                Text(emptyLine)
                    .font(.chinHand)
                    .foregroundStyle(Ink.textSoft)
                    .padding(.horizontal, Space.margin)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.snug) {
                        content()
                    }
                    .padding(.horizontal, Space.margin)
                    // Rails clip their own shadows without this; a card whose shadow is cut
                    // off at the scroll edge reads as a rendering bug. Hard shadows sit
                    // entirely outside the block, so this needs to clear the full drop.
                    .padding(.vertical, Space.tight + Sticker.drop)
                }
            }
        }
    }
}

/// Editing who you are. Two fields, because a profile people actually fill in is one that
/// fits on a single screen with the keyboard up.
struct IdentityEditor: View {
    @Bindable var record: MeRecord

    @Environment(\.modelContext) private var context

    var body: some View {
        SheetShell("You") {
            VStack(alignment: .leading, spacing: Space.step) {
                field("What you go by", text: $record.handle, placeholder: "matthew")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                field(
                    "What you're into",
                    text: $record.bio,
                    placeholder: "Builds things, walks everywhere, always knows a coffee place."
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.margin)
        }
        .onDisappear { try? context.save() }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Space.hair) {
            Text(label)
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
            TextField(placeholder, text: text, axis: .vertical)
                .font(.chinBody)
                .foregroundStyle(Ink.text)
                .padding(Space.snug)
                .background(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(Ink.groundRaised)
                )
        }
    }
}
