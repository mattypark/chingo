import SwiftUI
import SwiftData
import ChinGoDesign
import ChinGoEngine

/// Everyone you have caught.
///
/// Sorted by tier and then by how recently you saw them, so the people you actually spend
/// time with are at the top. Deliberately not a leaderboard and deliberately not a count —
/// the number of friends you have is the least interesting fact about them.
struct AlbumScreen: View {
    @Query(sort: \FriendRecord.metDate, order: .reverse) private var friends: [FriendRecord]
    @State private var selected: FriendRecord?

    private var ordered: [FriendRecord] {
        friends.sorted {
            $0.tier == $1.tier ? $0.metDate > $1.metDate : $0.tier > $1.tier
        }
    }

    var body: some View {
        SheetShell("Album") {
            if friends.isEmpty {
                empty
            } else {
                grid
            }
        }
        .sheet(item: $selected) { friend in
            CardDetail(friend: friend)
                .presentationBackground(Ink.ground)
                .presentationCornerRadius(30)
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 18
            ) {
                ForEach(ordered) { friend in
                    Button { selected = friend } label: {
                        CardView(face: friend.face, width: 158)
                    }
                    .buttonStyle(SquashButtonStyle())
                }
            }
            .padding(20)
        }
    }

    private var empty: some View {
        VStack(spacing: Space.tight) {
            Spacer()
            Text("Nobody yet")
                .font(.chinTitle)
                .foregroundStyle(Ink.text)
            Text("Catch someone and they'll show up here.")
                .font(.chinHand)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.section)
            Spacer()
            // An empty state is where an app is most obviously a database with no rows in
            // it. The bear leaning in from the bottom is the cheapest possible way to make
            // it read as a room nobody has arrived at yet.
            Image("CornerBear")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
                .offset(y: 46)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

/// One card, big, with the thing the tier ladder still wants from you.
struct CardDetail: View {
    let friend: FriendRecord

    var body: some View {
        VStack(spacing: 20) {
            CardView(face: friend.face, width: 300)
                .padding(.top, 28)

            VStack(spacing: 6) {
                Text(friend.tier.title)
                    .chinLabelStyle()
                    .foregroundStyle(Ink.textFaint)

                if let next = Bond.nextTierRequirement(for: friend.history) {
                    // Deterministic progression: you always know exactly what is left. This
                    // is the line that keeps the tier ladder from feeling like a slot machine.
                    Text(next)
                        .font(.chinCallout)
                        .foregroundStyle(Ink.textSoft)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Nothing left to prove.")
                        .font(.chinHand)
                        .foregroundStyle(Ink.textSoft)
                }
            }
            .padding(.horizontal, 34)

            Spacer(minLength: 20)
        }
    }
}

extension FriendRecord {
    /// The stored record, as something the design package can draw. Keeps SwiftData out of
    /// ChinGoDesign entirely, so the card stays previewable with no store at all.
    var face: CardFace {
        CardFace(
            id: id,
            handle: handle,
            metCity: metCity,
            metDate: metDate,
            traits: traits,
            move: move.isEmpty ? "You haven't written their move yet." : move,
            moveAuthor: "you",
            tier: tier.rawValue,
            placesShared: distinctPlaceCount,
            catches: catches.count,
            portrait: nil
        )
    }
}
