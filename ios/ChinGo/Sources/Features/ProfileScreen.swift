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

    @State private var selected: FriendRecord?

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
                    header
                    peopleRail
                    photoRail
                    placeChips
                }
                .padding(.bottom, Space.step)
            }
        }
        .sheet(item: $selected) { friend in
            SheetShell(friend.handle) {
                CardDetail(friend: friend)
            }
            .presentationBackground(Ink.ground)
            .presentationCornerRadius(Radius.surface)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: Space.snug) {
            ZStack {
                Circle()
                    .fill(Ink.groundRaised)
                    .elevated(.card)
                Circle()
                    .stroke(Ink.groundSunk, lineWidth: 5)
                    .padding(4)
                Circle()
                    .trim(from: 0, to: max(0.02, state.levelProgress))
                    .stroke(Ink.signal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)
                // Sized to sit inside the ring whole. Filling the circle crops the ears,
                // and the ears are most of what makes it read as a bear rather than a blob.
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62)
                    .offset(y: 4)
            }
            .frame(width: 116, height: 116)

            Text("Level \(state.level)")
                .font(.chinTitle)
                .foregroundStyle(Ink.text)

            Text("\(state.xp) XP")
                .font(.chinCallout)
                .foregroundStyle(Ink.textSoft)
                .contentTransition(.numericText())

            HStack(spacing: 0) {
                stat("\(catches.filter { $0.kind == "snap" }.count)", "meetups")
                Divider().frame(height: 28)
                stat("\(friends.count)", friends.count == 1 ? "person" : "people")
                Divider().frame(height: 28)
                stat("\(state.streakWeeks)", state.streakWeeks == 1 ? "week" : "weeks")
            }
            .padding(.vertical, Space.snug)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Ink.groundRaised)
                    .elevated(.low)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.margin)
        .padding(.top, Space.inset)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.custom(Typeface.bagel, size: 20))
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
                    .elevated(.low)

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
                    .font(.chinCallout)
                    .foregroundStyle(Ink.text)
                    .padding(.horizontal, Space.snug)
                    .padding(.vertical, Space.tight)
                    .background(Capsule().fill(Ink.groundRaised))
                    .overlay(Capsule().strokeBorder(Ink.groundSunk, lineWidth: 1.5))
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
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
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
                    // off at the scroll edge reads as a rendering bug.
                    .padding(.vertical, Space.tight)
                }
            }
        }
    }
}
