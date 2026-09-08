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
    @State private var projection = GlobeProjection()
    @AppStorage("globeLook") private var look: GlobeLook = .globe
    @State private var pickingLook = false
    /// Who the camera is looking at, and a counter so tapping the same person twice flies
    /// back to them rather than doing nothing.
    @State private var focus: GlobePin?
    @State private var focusToken = 0
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
                    GlobeMap(
                        pins: pins,
                        fitToken: fitToken,
                        projection: projection,
                        look: look,
                        focus: focus,
                        focusToken: focusToken
                    )
                    .ignoresSafeArea(edges: .horizontal)
                    .overlay { tokens }
                    .overlay(alignment: .bottom) { faces }

                    if pins.isEmpty { nobodyYet }
                } else {
                    invitation
                }

                VStack(alignment: .leading, spacing: Space.tight) {
                    header
                    if pickingLook {
                        GlobeLookBar(selection: $look)
                            .padding(.horizontal, Space.margin)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .sheet(item: $selected) { pin in
            GlobePinCard(pin: pin)
                .presentationDetents([.height(230)])
        }
        .sheet(isPresented: $managing) {
            GlobeSharingSheet()
        }
        // On the pins arriving, not on appear. The query is still empty at the moment the
        // view appears, so an `onAppear` that reads `pins.first` always saw nothing and the
        // camera never moved.
        .onChange(of: pins.count, initial: true) { _, _ in
            // Opens on somebody rather than on an empty planet. Framing everybody is the
            // honest default only when everybody fits, and on a sphere they often cannot --
            // an opening shot of the Pacific with all your friends over the horizon looks
            // like the feature is broken.
            guard focus == nil, let first = pins.first else { return }
            focus = first
            focusToken += 1
        }
    }

    /// The friends, drawn over the globe rather than into it. See `GlobeProjection`.
    private var tokens: some View {
        GeometryReader { _ in
            ForEach(pins) { pin in
                if let point = projection.point(for: pin.coordinate) {
                    GlobeToken(pin: pin, showsName: true) { selected = pin }
                        .position(x: point.x, y: point.y)
                }
            }
        }
        // Reading `tick` is what re-places these as the planet turns. Without it they are
        // placed once and then sit still while the world spins underneath them.
        .id(projection.tick)
    }

    /// Everyone visible, along the bottom. Tap to fly.
    ///
    /// Find My's list, reduced to faces because these are already tokens rather than rows and
    /// a name is repeated under each one on the globe itself.
    private var faces: some View {
        Group {
            if pins.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.tight) {
                        ForEach(pins) { pin in
                            Button {
                                focus = pin
                                focusToken += 1
                            } label: {
                                GlobeToken(pin: pin, showsName: false) {}
                                    .allowsHitTesting(false)
                                    .opacity(focus?.id == pin.id ? 1 : 0.72)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Fly to \(pin.handle)")
                        }
                    }
                    .padding(.horizontal, Space.margin)
                    .padding(.top, Space.tight)
                    // Clear of Apple's attribution, which is not optional -- the maps legal
                    // notice has to stay visible and unobstructed.
                    .padding(.bottom, Space.section + Space.step)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Space.tight) {
            // The title is gone and the layer picker has its place. On a screen that is
            // entirely one map, a word naming the screen is the least useful thing that could
            // occupy the corner -- you know where you are, and what you might want is to
            // change what you are looking at.
            Button { withAnimation(Motion.surface) { pickingLook.toggle() } } label: {
                Image(systemName: pickingLook ? "xmark" : "square.3.layers.3d")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Ink.text)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(StickerCircleStyle(fill: Ink.groundRaised))
            .hitTarget()
            .accessibilityLabel("Change how the map looks")

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

/// One friend on the globe: their bear in a ring, with their handle under it.
///
/// A circle rather than a teardrop pin. A pin points at a building; on a globe the honest
/// claim is "somewhere around here", and a round token makes that claim without implying a
/// precision the position does not have.
private struct GlobeToken: View {
    let pin: GlobePin
    var showsName: Bool = true
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Group {
                    if let bear = BearIcons.all[BearIcons.name(accent: pin.accent, phase: nil)] {
                        Image(uiImage: bear).resizable().scaledToFit().padding(4)
                    }
                }
                .frame(width: 46, height: 46)
                .background(Circle().fill(Accent.at(pin.accent).signalLift))
                .overlay(Circle().strokeBorder(Ink.text, lineWidth: 3))

                if showsName {
                Text(pin.handle)
                    .font(.custom(Typeface.bagel, size: 12))
                    .foregroundStyle(Ink.text)
                    // A hard cream offset rather than a blurred halo, so the label still
                    // belongs to this app while sitting on a photograph of the Pacific.
                    .shadow(color: Ink.groundRaised, radius: 0, x: 1.5, y: 1.5)
                    .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pin.handle), on the globe")
    }
}
