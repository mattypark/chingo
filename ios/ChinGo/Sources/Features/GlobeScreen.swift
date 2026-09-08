import SwiftUI
import SwiftData
import CoreLocation
import ChinGoDesign
import ChinGoEngine

/// Everybody, on the planet.
///
/// Deliberately not a live tracker. The rules it draws are in `ChinGoEngine.GlobeSharing`, and
/// the two that shape this screen most are that nobody appears without both people having said
/// yes, and that a person who is not appearing is never explained. There is no "paused" chip,
/// no "last seen 3 days ago", no greyed-out row implying somebody used to be here. Somebody
/// quiet is simply absent, and that is what makes leaving the feature free.
///
/// It also means the empty state is the *normal* state for a new install, so it is written as
/// an invitation rather than as an error.
struct GlobeScreen: View {
    @Environment(\.accent) private var accent
    @Environment(\.modelContext) private var context

    @Query(sort: \FriendRecord.metDate, order: .reverse) private var friends: [FriendRecord]
    @Query private var me: [MeRecord]

    @State private var selected: GlobePin?
    @State private var fitToken = 0
    @State private var ready = 0
    @State private var managing = false

    private var identity: MeRecord? { me.first }
    private var globeEnabled: Bool { identity?.globeEnabled ?? false }
    private var paused: Bool { identity?.sharingPaused ?? false }

    /// Everybody the rule says you may see, and nobody else.
    ///
    /// The filter runs through `GlobeSharing.visibility` rather than reading the flags here,
    /// so this view cannot accidentally check for a position and then decide separately
    /// whether it is allowed to draw it.
    private var pins: [GlobePin] {
        friends.compactMap { friend in
            let grant = GlobeSharing.Grant(
                iShare: friend.iShareWith,
                theyShare: friend.theyShareWithMe
            )
            guard case let .somewhere(lat, lon, age) = GlobeSharing.visibility(
                of: grant,
                globeEnabled: globeEnabled,
                sharingPaused: paused,
                latitude: friend.globeLatitude,
                longitude: friend.globeLongitude,
                updatedAt: friend.globeUpdatedAt
            ) else { return nil }

            return GlobePin(
                id: friend.id,
                handle: friend.handle,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                age: age,
                accent: friend.accentIndex
            )
        }
    }

    var body: some View {
        SheetShell {
            ZStack(alignment: .top) {
                if globeEnabled {
                    GlobeMap(pins: pins, accent: accent, fitToken: fitToken, ready: $ready) { selected = $0 }
                        .ignoresSafeArea(edges: .horizontal)

                    if pins.isEmpty { nobodyYet }
                } else {
                    invitation
                }

                header
            }
        }
        .sheet(item: $selected) { pin in
            GlobePinCard(pin: pin)
                .presentationDetents([.height(230)])
        }
        .sheet(isPresented: $managing) {
            GlobeSharingSheet()
        }
        .onAppear { fitToken += 1 }
    }

    private var header: some View {
        HStack(spacing: Space.tight) {
            Text("Globe")
                .font(.chinTitle)
                .foregroundStyle(Ink.text)
                .shadow(color: Ink.groundRaised, radius: 0, x: 2, y: 2)

            Spacer()

            if globeEnabled {
                // Pause is the loudest control on the screen after the title, on purpose. The
                // way out of a location feature should never be the hardest thing to find in
                // it.
                Button {
                    guard let identity else { return }
                    identity.sharingPaused.toggle()
                    try? context.save()
                } label: {
                    Text(paused ? "Paused" : "Pause")
                        .font(.custom(Typeface.bagel, size: 14))
                        .foregroundStyle(paused ? accent.onSignal : Ink.text)
                        .padding(.horizontal, Space.snug)
                        .padding(.vertical, Space.hair + 2)
                }
                .buttonStyle(
                    StickerButtonStyle(
                        fill: paused ? accent.signal : Ink.groundRaised,
                        radius: Radius.control
                    )
                )
                .hitTarget()

                Button {
                    managing = true
                } label: {
                    Image(systemName: "person.2.badge.gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Ink.text)
                        .padding(Space.tight)
                }
                .buttonStyle(StickerCircleStyle(fill: Ink.groundRaised))
                .hitTarget()
                .accessibilityLabel("Who can see you")
            }
        }
        .padding(.horizontal, Space.margin)
        .padding(.top, Space.snug)
    }

    /// The globe is on and nobody is on it. Says what to do, not what went wrong.
    private var nobodyYet: some View {
        VStack(spacing: Space.tight) {
            Text("Nobody's here yet.")
                .font(.chinBody)
                .foregroundStyle(Ink.text)
            Text("You'll both have to say yes. Ask a friend and turn them on.")
                .font(.chinFootnote)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)

            // The label carries the padding and the type, not the Button. Modifiers hung off
            // the Button itself style the wrapper and leave the label at system defaults
            // inside a box sized for something else -- which is a clipped word on a coloured
            // pill, and looks like a layout bug rather than the mistake it is.
            Button { managing = true } label: {
                Text("Choose who")
                    .font(.custom(Typeface.bagel, size: 15))
                    .foregroundStyle(accent.onSignal)
                    .padding(.horizontal, Space.inset)
                    .padding(.vertical, Space.tight)
            }
            .buttonStyle(StickerButtonStyle(fill: accent.signal, radius: Radius.control))
            .hitTarget()
            .padding(.top, Space.hair)
        }
        .padding(Space.inset)
        .sticker(fill: Ink.groundRaised, radius: Radius.card)
        .padding(.horizontal, Space.margin)
        .padding(.top, 76)
    }

    /// The feature has never been switched on. This is the normal state of a fresh install,
    /// so it is written as an offer rather than as a setup chore.
    private var invitation: some View {
        VStack(spacing: Space.step) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(accent.signal)

            Text("See where your people are")
                .font(.chinTitle)
                .foregroundStyle(Ink.text)

            Text("""
                Only friends you pick, and only if they pick you back. \
                You can pause any time, and nobody is told when you do.
                """)
                .font(.chinBody)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.margin)

            Button {
                guard let identity else { return }
                identity.globeEnabled = true
                try? context.save()
                managing = true
            } label: {
                Text("Turn it on")
                    .font(.custom(Typeface.bagel, size: 17))
                    .foregroundStyle(accent.onSignal)
                    .padding(.horizontal, Space.section)
                    .padding(.vertical, Space.snug)
            }
            .buttonStyle(StickerButtonStyle(fill: accent.signal, radius: Radius.surface))
            .hitTarget()

            Spacer()
        }
    }
}

/// Who somebody is, and how old the fix is.
///
/// The age is never rounded away to "now". A dot on a world map is read as live unless it
/// says otherwise, and a six-hour-old position in the wrong city is worse than no position.
private struct GlobePinCard: View {
    @Environment(\.accent) private var accent
    let pin: GlobePin

    var body: some View {
        VStack(spacing: Space.snug) {
            if let bear = BearIcons.all[BearIcons.name(accent: pin.accent, phase: nil)] {
                Image(uiImage: bear)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 62)
            }

            Text(pin.handle)
                .font(.custom(Typeface.bagel, size: 26))
                .foregroundStyle(Ink.text)

            Text(freshness)
                .font(.chinFootnote)
                .foregroundStyle(Ink.textSoft)
        }
        .padding(Space.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.ground)
    }

    private var freshness: String {
        let minutes = Int(pin.age / 60)
        if minutes < 2 { return "Just now" }
        if minutes < 60 { return "About \(minutes) minutes ago" }
        let hours = Int((pin.age / 3600).rounded())
        return hours == 1 ? "About an hour ago" : "About \(hours) hours ago"
    }
}
