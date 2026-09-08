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
    @AppStorage("globeLook") private var look: GlobeLook = GlobeLook.fallback
    @State private var pickingLook = false
    @Environment(\.dismiss) private var dismiss
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
                accent: friend.accentIndex,
                portraitFile: friend.portraitFile
            )
        }
    }

    var body: some View {
        ZStack {
            if globeEnabled {
                Group {
                    if look.isSphere {
                        GlobeMap(
                            pins: pins,
                            fitToken: fitToken,
                            projection: projection,
                            look: look,
                            focus: focus,
                            focusToken: focusToken
                        )
                    } else {
                        FlatGlobeMap(
                            accent: accent,
                            projection: projection,
                            focus: focus,
                            focusToken: focusToken
                        )
                    }
                }
                .overlay { tokens }

                if pins.isEmpty { nobodyYet }
            } else {
                Ink.ground
                invitation
            }

            // The chrome floats on the map rather than being framed by a sheet.
            //
            // This used to sit inside `SheetShell`, which put a band of cream above and below
            // it and a close button on its own row -- so the screen read as a picture of a map
            // inside the app rather than as the map. A map with a margin is a diagram.
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                bottomBar
            }
        }
        .ignoresSafeArea()
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
            // `tick` is read here, inside the `GeometryReader`, and the `.id` hangs on this
            // inner stack rather than on the whole layer.
            //
            // It used to be on the outside, which meant `body` itself took a dependency on a
            // counter that advances on every frame of every camera move -- so a pinch
            // re-walked the friends query, rebuilt the map representable and tore down every
            // token sixty times a second. Scoping it keeps the one thing that has to be
            // recomputed, which is where each token sits.
            ZStack {
                ForEach(pins) { pin in
                    if let point = projection.point(for: pin.coordinate) {
                        GlobeToken(pin: pin) { selected = pin }
                            // Lifted by half its own height so the tip lands on the
                            // coordinate. `.position` centres, and a marker centred on a
                            // point is a marker that is not on it.
                            .position(x: point.x, y: point.y - GlobeToken.height / 2)
                    }
                }
            }
            .id(projection.tick)
        }
    }

    /// Everyone visible, along the bottom. Tap to fly.
    ///
    /// Find My's list, reduced to faces because these are already tokens rather than rows and
    /// a name is repeated under each one on the globe itself.
    private var faces: some View {
        Group {
            if pins.count > 1 {
                // An `HStack`, not a `ScrollView`, and that is a bug fix rather than a
                // simplification. A `ScrollView` is greedy: it accepts the whole size it is
                // offered, and an overlay offers the map's entire frame. So this laid out at
                // full screen, and a `UIScrollView` claims every touch inside its bounds
                // regardless of having no background -- which is why the globe could not be
                // pinched or panned, and why tapping a friend's token did nothing either.
                //
                // It was gated on `pins.count > 1`, so the bug only appeared once you had two
                // friends sharing. With one, zoom worked fine.
                //
                // Nothing is lost: this is a handful of friends, not a feed.
                HStack(spacing: Space.tight) {
                        ForEach(pins) { pin in
                            Button {
                                focus = pin
                                focusToken += 1
                            } label: {
                                GlobeToken(pin: pin, isMarker: false) {}
                                    .allowsHitTesting(false)
                                    .opacity(focus?.id == pin.id ? 1 : 0.72)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Fly to \(pin.handle)")
                        }
                }
                // A tray, not loose tokens. Without a surface behind them these read as three
                // more people standing in the Atlantic -- identical objects to the ones
                // actually pinned on the map, in a place nobody is.
                .padding(.horizontal, Space.snug)
                .padding(.vertical, Space.tight)
                .background(Capsule().fill(Ink.groundRaised))
                .overlay(Capsule().strokeBorder(Ink.text, lineWidth: 3))
                .compositingGroup()
                .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)
                .padding(.horizontal, Space.margin)
            }
        }
    }

    /// Layers on the left, and the two things that are about *you* on the right -- the way
    /// Bump puts your own face and your alerts in that corner.
    private var topBar: some View {
        HStack(alignment: .top, spacing: Space.tight) {
            VStack(alignment: .leading, spacing: Space.tight) {
                Button { withAnimation(Motion.surface) { pickingLook.toggle() } } label: {
                    Image(systemName: pickingLook ? "xmark" : "square.3.layers.3d")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Ink.text)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(StickerCircleStyle(fill: Ink.groundRaised))
                .hitTarget()
                .accessibilityLabel("Change how the map looks")

                if pickingLook {
                    GlobeLookBar(selection: $look)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            Spacer(minLength: 0)

            if globeEnabled {
                // Pause stays the loudest control up here. The way out of a location feature
                // should never be the hardest thing to find in it.
                Button {
                    guard let identity else { return }
                    identity.sharingPaused.toggle()
                    try? context.save()
                } label: {
                    Text(paused ? "Paused" : "Pause")
                        .font(.custom(Typeface.bagel, size: 14))
                        .foregroundStyle(paused ? accent.onSignal : Ink.text)
                        .padding(.horizontal, Space.snug)
                        .padding(.vertical, Space.tight)
                }
                .buttonStyle(
                    StickerButtonStyle(
                        fill: paused ? accent.signal : Ink.groundRaised,
                        radius: Radius.pill
                    )
                )
                .hitTarget()

                PortraitWell(portraitFile: identity?.portraitFile, diameter: 40)
            }
        }
        .padding(.horizontal, Space.margin)
        .padding(.top, Space.section + Space.step)
    }

    /// Three round buttons along the bottom, which is where Bump puts the map's own verbs.
    ///
    /// The right-hand one is the way out, and it is deliberately in the same corner as the
    /// globe button that opened this screen. A door you leave by the handle you came in
    /// through does not need a label.
    private var bottomBar: some View {
        VStack(spacing: Space.snug) {
            if globeEnabled, pins.count > 1 { faces }

            // A centred cluster, not two corners.
            //
            // Measured off the reference rather than guessed: the circles are about 16.5% of
            // the screen's width and sit roughly 24.8% apart centre to centre, with the middle
            // one on the screen's own axis. Pushing them into opposite corners -- which is what
            // this was -- makes them read as two unrelated controls that happen to share a row,
            // which is exactly the mistake the home bar was built to fix.
            //
            // What is *not* copied is the material. Bump's chrome is Liquid Glass, translucent
            // and refractive; ours is flat fill with a hard outline and a zero-blur shadow, and
            // mixing the two would put two design languages on one screen.
            GeometryReader { geo in
                let size = min(geo.size.width * 0.165, 66)

                HStack(spacing: geo.size.width * 0.248 - size) {
                    roundButton(icon: "person.2.badge.gearshape.fill", label: "Sharing", size: size) {
                        managing = true
                    }
                    .opacity(globeEnabled ? 1 : 0)
                    .allowsHitTesting(globeEnabled)

                    roundButton(icon: "globe", label: "Everyone", size: size) {
                        fitToken += 1
                    }
                    .opacity(globeEnabled ? 1 : 0)
                    .allowsHitTesting(globeEnabled)

                    roundButton(icon: "map.fill", label: "Map", size: size) { dismiss() }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 92)
            .padding(.bottom, Space.step)
        }
    }

    private func roundButton(
        icon: String,
        label: String,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Space.hair) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(Ink.text)
                    .frame(width: size, height: size)
            }
            .buttonStyle(StickerCircleStyle(fill: Ink.groundRaised))
            .hitTarget()

            Text(label)
                .font(.custom(Typeface.bagel, size: 11))
                .foregroundStyle(Ink.text)
                // The label sits on the map, so it gets the same hard cream offset every other
                // piece of type over live ground in this app gets.
                .shadow(color: Ink.groundRaised, radius: 0, x: 1.5, y: 1.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
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
    /// False in the tray at the bottom of the screen, where the same avatar appears as a
    /// button rather than as a marker. A stem there would be pointing at a row of buttons.
    var isMarker: Bool = true
    var onTap: () -> Void

    /// How tall the whole marker is, tip included. The caller lifts by this so the *tip*
    /// lands on the coordinate rather than the middle of the face.
    static let height: CGFloat = 62

    private static let face: CGFloat = 46
    private static let stem: CGFloat = 10

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                avatar

                if isMarker {
                    // Sits over the stem rather than under the tip, so the label never covers
                    // the point the marker is claiming.
                    Text(pin.handle)
                        .font(.custom(Typeface.bagel, size: 12))
                        .foregroundStyle(Ink.text)
                        // A hard cream offset rather than a blurred halo, so the label still
                        // belongs to this app while sitting on somebody else's map.
                        .shadow(color: Ink.groundRaised, radius: 0, x: 1.5, y: 1.5)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(y: -2)
                        .zIndex(1)
                }

                if isMarker { stem }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pin.handle), on the map")
    }

    /// Their face if they set one, otherwise their bear.
    ///
    /// The bear is not a placeholder for a missing photo -- it is what the map calls them and
    /// it is in the colour they picked, so somebody who never adds a photo has a complete
    /// identity rather than a greyed-out one.
    private var avatar: some View {
        Group {
            if let portrait = PhotoStore.loadPortrait(pin.portraitFile) {
                Image(uiImage: portrait).resizable().aspectRatio(contentMode: .fill)
            } else if let bear = BearIcons.all[BearIcons.name(accent: pin.accent, phase: nil)] {
                Image(uiImage: bear).resizable().scaledToFit().padding(4)
            }
        }
        .frame(width: Self.face, height: Self.face)
        .background(Circle().fill(Accent.at(pin.accent).signalLift))
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Ink.text, lineWidth: 3))
        .zIndex(2)
    }

    /// The bit that makes it a pin rather than a floating token.
    ///
    /// A circle centred on a coordinate claims a place the size of the circle; a tip claims a
    /// point. That is the whole difference, and it is why the label goes above the stem rather
    /// than below it -- the one thing that must never be covered is the spot.
    private var stem: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Ink.text)
                .frame(width: 3, height: Self.stem)

            Circle()
                .fill(Ink.text)
                .frame(width: 7, height: 7)
                .offset(y: 3)
        }
        .frame(height: Self.stem)
    }
}
