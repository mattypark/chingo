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

    /// Injected rather than `@Environment(\.dismiss)`, and that is the whole reason this
    /// screen is no longer a `.fullScreenCover`: a presentation gives no transition hook and
    /// `matchedGeometryEffect` cannot cross a presentation boundary, so the globe now lives
    /// in the map's own stack and is told how to leave it.
    var onClose: () -> Void
    /// Debug only: a counter the map bumps to trigger the real exit from outside. See
    /// `DemoSeed.tour`.
    var leaveOn: Int = 0

    @State private var selected: GlobePin?
    @State private var fitToken = 0
    @State private var projection = GlobeProjection()
    @AppStorage("globeLook") private var look: GlobeLook = GlobeLook.fallback
    @State private var pickingLook = false
    /// False for the first frame, so the chrome has somewhere to pop in from. Also what the
    /// exit runs backwards through: it drops before `onClose`, so the globe's own chrome is
    /// gone before the screen is taken away.
    @State private var appeared = false
    /// How far through being drawn this screen's chrome is. Four pieces: the layers button,
    /// the pause pill, the faces tray and the bottom bar.
    private var drawn: DrawnScreen { DrawnScreen(appeared ? 1 : 0, pieces: 2) }
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
                topBar.pops(hidden: !appeared, rank: 0)
                Spacer(minLength: 0)
                bottomBar.pops(hidden: !appeared, rank: 1)
            }
        }
        .ignoresSafeArea()
        // The planet itself does not pop -- it is the ground, not a thing printed on it, and
        // a shrinking world would read as the screen zooming rather than as chrome arriving.
        //
        // `Motion.tap` and not `Motion.surface`: at surface speed the world took 0.42s to
        // come up over the opaque floor beneath it, and because the map's chrome had already
        // left there were four frames of nothing but cream in the middle of the swap. Short
        // enough and the new world is under the old chrome while that chrome is still leaving,
        // which is the whole illusion -- the ground changes, the stickers come off.
        .opacity(appeared ? 1 : 0)
        .task {
            // `Motion.draw`, not a surface spring: the chrome is being drawn on, and the
            // curve has to be the same one the reveal card uses or the app has two different
            // ideas of how long a thing takes to appear.
            withAnimation(Motion.reduceMotion ? nil : Motion.draw) { appeared = true }
        }
        .onChange(of: leaveOn) { _, _ in leave() }
        .sheet(item: $selected) { pin in
            GlobePinCard(pin: pin)
                .presentationDetents([.height(230)])
        }
        .sheet(isPresented: $managing) {
            GlobeSharingSheet()
                // Detents, because this sheet was presented at full height whatever it held.
                // With a handful of friends that is a short list and a screen of white under
                // it; with none it was two lines floating in the middle of nothing. Medium
                // fits the common case and it drags up when the list is long enough to need it.
                .presentationDetents([.medium, .large])
                .presentationBackground(Ink.ground)
                .presentationCornerRadius(30)
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
                // Says what it *is*, not what tapping it does.
                //
                // It read "Pause", which is a verb with no object -- pause what, and is it
                // paused now or is that the button that would pause it. The map's own
                // discoverability pill next door already solved this: a dot and a state word,
                // "Out" or "Hidden". Same shape, same reading, one fewer thing to learn.
                Button {
                    guard let identity else { return }
                    identity.sharingPaused.toggle()
                    try? context.save()
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(paused ? Ink.textFaint : Ink.jade)
                            .frame(width: 8, height: 8)
                        Text(paused ? "Paused" : "Live")
                            .font(.custom(Typeface.bagel, size: 14))
                            .foregroundStyle(paused ? accent.onSignal : Ink.text)
                    }
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
                .accessibilityLabel(
                    paused
                        ? "Sharing is paused. Tap to share your place again."
                        : "Sharing your place. Tap to pause it."
                )

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

            // One slab with three cells, built the way `HomeBar`'s is: equal cells at
            // `maxWidth: .infinity` separated by 3pt ink rules, the whole thing wearing a
            // single sticker.
            //
            // This was three free-floating circles at a measured percentage spacing, and two
            // things were wrong with it. They read as three unrelated controls that happened
            // to share a row -- the exact fault the home bar was built to fix -- and each wore
            // its own outline and hard shadow, so putting them on a surface would have been a
            // sticker inside a sticker. The cells carry no shadow of their own, for the same
            // reason the home bar's do not.
            HStack(spacing: 0) {
                cell(icon: "person.2.badge.gearshape.fill", label: "Sharing", enabled: globeEnabled) {
                    managing = true
                }
                rule
                cell(icon: "globe", label: "Everyone", enabled: globeEnabled) {
                    fitToken += 1
                }
                rule
                cell(icon: "map.fill", label: "Map", enabled: true) { leave() }
            }
            .frame(height: 74)
            .drawnSticker(fill: Ink.groundRaised, radius: Radius.surface, drawn: drawn.piece(1))
            .padding(.horizontal, Space.margin)
            .padding(.trailing, Sticker.drop)
            .padding(.bottom, Space.section)
        }
    }

    /// 3pt, in ink, like every other line in this language.
    private var rule: some View {
        Rectangle()
            .fill(Ink.text)
            .frame(width: 3)
            .padding(.vertical, Space.snug)
    }

    /// The globe's chrome leaves before the globe does.
    ///
    /// Dropping `appeared` and calling `onClose` in the same breath would take the screen away
    /// underneath its own exit, so nothing would be seen to leave -- the map would simply be
    /// there again. The wait is one `Motion.dismiss` plus the last piece's stagger.
    private func leave() {
        guard !Motion.reduceMotion else { return onClose() }

        withAnimation(Motion.erase) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(340))
            onClose()
        }
    }

    private func cell(
        icon: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Ink.text)
                Text(label)
                    .font(.custom(Typeface.bagel, size: 11))
                    .foregroundStyle(Ink.textSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(SquashButtonStyle())
        .opacity(enabled ? 1 : 0.35)
        .allowsHitTesting(enabled)
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
        // The ring takes *their* colour, not ink.
        //
        // A deliberate departure from the 3pt-ink rule, and only here. On a map covered in
        // identical circles the ring is the only thing carrying who somebody is at a glance --
        // ink on every one of them makes a row of anonymous holes, and the photo inside is far
        // too small at this size to tell two people apart.
        .overlay(Circle().strokeBorder(Accent.at(pin.accent).signal, lineWidth: 4))
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
                .fill(Accent.at(pin.accent).signal)
                .frame(width: 3, height: Self.stem)

            Circle()
                .fill(Accent.at(pin.accent).signal)
                .frame(width: 7, height: 7)
                .offset(y: 3)
        }
        .frame(height: Self.stem)
    }
}
