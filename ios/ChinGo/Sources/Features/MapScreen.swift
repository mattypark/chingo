import SwiftUI
import SwiftData
import CoreLocation
import ChinGoDesign
import ChinGoEngine

/// The home screen: a world with things floating over it.
///
/// The architecture deliberately follows the one Pokémon GO uses, because for a one-handed
/// map app it is correct — the map owns every pixel, the player is fixed at the centre, and
/// controls are small rounded objects detached from the edges. Everything specific to
/// Niantic is absent: no sphere, no aim ring, no gym pillars, no basemap of theirs.
struct MapScreen: View {
    @Environment(\.accent) private var accent

    @Bindable var state: MapState
    @Environment(\.modelContext) private var context
    @Query private var memories: [MemoryRecord]
    @Query private var catches: [CatchRecord]
    @Query private var me: [MeRecord]

    let location: LocationService

    @State private var camera = MapCamera()
    @State private var openMemory: MemoryRecord?
    @State private var showProfile = false
    @State private var catchMenu = false
    @State private var deckMenu = false
    @State private var showCatch = false
    @State private var showAlbum = false
    @State private var showGlobe = false
    @State private var showAddFriend = false
    @State private var showMyHandle = false
    @State private var catchPulse = 0
    /// Which name in the nearby rail is in focus.
    @State private var focusedNearby = 0
    /// Which step of the walk every bear is on. One counter for everybody: a crowd all
    /// stepping in time is a marching band, so each bear offsets from it by its own id.
    @State private var walkPhase = 0
    /// Lets the reveal card find its bear on screen.
    @State private var projection = MapProjection()
    /// Who is currently revealed. Held rather than derived so it can hang on past the
    /// interaction radius -- see `revealed`.
    @State private var revealedID: String?
    /// Bumped when somebody new comes into range, so the haptic fires on the crossing rather
    /// than on every frame they stay there.
    @State private var reveals = 0
    /// The memory currently being mentioned, if any. See `MemoryNudge`.
    @State private var nudge: MemoryRecord?
    /// The photo currently flying into the album, if any.
    @State private var flying: UIImage?
    @State private var flown = false

    /// Screen-relative direction of the nearest memory, for the bear to lean toward.
    ///
    /// Relative to the camera, not to north — the bear leans toward where the thing appears
    /// on screen, which is the only frame of reference the person holding the phone has.
    private var glanceBearing: Double? {
        guard let nearest = visibleMemories.first else { return nil }
        let dLon = nearest.longitude - here.lon
        let dLat = nearest.latitude - here.lat
        guard abs(dLon) > 1e-9 || abs(dLat) > 1e-9 else { return nil }
        let absolute = atan2(dLon, dLat) * 180 / .pi
        return absolute - camera.bearing
    }

    /// How many bears may be on screen before it stops being a map.
    ///
    /// Eight. Past that a lunchtime corner downtown is an unreadable pile and a battery
    /// complaint, and the people beyond the cap are not lost -- they are still in the rail
    /// and still in the nearby list.
    private static let visibleBears = 8

    /// Everyone near enough to draw, nearest first.
    private var bears: [BearMark] {
        state.nearby
            .sorted { $0.approxMetres < $1.approxMetres }
            .prefix(Self.visibleBears)
            .map { person in
                BearMark(
                    id: person.id,
                    coordinate: person.coordinate,
                    icon: BearIcons.name(
                        accent: person.accent,
                        // Standing still is an idle, not a frozen walk frame.
                        phase: person.course == nil
                            ? nil
                            : walkPhase + abs(person.id.hashValue % BearIcons.walkFrames)
                    )
                )
            }
    }

    /// Roughly how tall a bear stands on screen, in points, at the zoom the map sits at.
    /// Measured off the icon rather than derived: `BearIcons.side` is 192pt and the symbol
    /// layer scales it to about 15% at the zoom the map opens on.
    private static let bearHeight: CGFloat = 28

    /// The nearest person inside the interaction ring, with hysteresis.
    ///
    /// Somebody already revealed stays revealed until they pass `Radar.releaseMetres`, a third
    /// further out. Without that gap phone GPS drift alone flickers the card several times a
    /// minute for anybody standing near the boundary.
    private var revealed: NearbyPerson? {
        if let held = revealedID,
           let still = state.nearby.first(where: { $0.id == held }),
           Double(still.approxMetres) <= Radar.releaseMetres {
            return still
        }
        return state.nearby
            .filter { Double($0.approxMetres) <= Radar.interactionMetres }
            .min { $0.approxMetres < $1.approxMetres }
    }

    /// The card, over the bear it belongs to.
    private var revealLayer: some View {
        GeometryReader { geo in
            if let person = revealed, let point = projection.point(for: person.coordinate) {
                // Nudged inboard only far enough to stay on screen, with the stem left
                // pointing at the bear. An earlier version also kept it clear of the nearby
                // rail, which meant a bear near the right edge got a card 150pt away from
                // it and a stem that could only reach 78 -- a line pointing at nothing.
                // The rail steps aside instead; see `chrome`.
                let half = RevealCard.width / 2
                let left = Space.inset + half
                let right = geo.size.width - Space.inset - half
                let x = min(max(point.x, left), max(left, right))

                RevealCard(
                    person: person,
                    stemOffset: point.x - x,
                    onAdd: { showAddFriend = true },
                    onCatch: { showCatch = true }
                )
                // Clear of the bear's head, not resting on it. The bear is anchored at its
                // feet and stands about `bearHeight` tall at this zoom, and the stem hangs
                // below the card, so the whole lot has to come off the top.
                .position(x: x, y: point.y - Self.bearHeight - RevealCard.stem - 48)
            }
        }
        // The map ignores the safe area and this has to be measured in the same space, or
        // every card lands a status bar's height below the bear it belongs to.
        .ignoresSafeArea()
        // Reading `tick` is what re-runs this as the camera moves. Without it the card is
        // placed once and then sits still while the map slides underneath it.
        .id(projection.tick)
        .feedback(.pick, on: reveals)
        .onChange(of: revealed?.id) { previous, next in
            revealedID = next
            if next != nil, next != previous { reveals += 1 }
        }
    }

    private var here: (lat: Double, lon: Double) {
        let c = location.coordinateOrFallback
        return (c.latitude, c.longitude)
    }

    private var cell: String {
        GeoCell(latitude: here.lat, longitude: here.lon).id
    }

    /// Whether walking past a memory is allowed to say anything. On unless turned off, and
    /// absent only before onboarding has written a record.
    private var wantsNudges: Bool { me.first?.wantsMemoryNudges ?? true }

    /// How long a nudge stays on screen before it takes itself away.
    ///
    /// Long enough to read twice while walking, short enough that it is gone before it turns
    /// into part of the furniture. It is also dismissible, so this is the ceiling rather than
    /// the expected lifetime.
    private static let nudgeLifetime: Duration = .seconds(8)

    /// Look for something worth mentioning, and mention at most one thing.
    ///
    /// Called on every cell change rather than on every fix. A fix arrives every 25 metres and
    /// re-running the whole candidate list that often would be work for nothing -- the radius
    /// is 150 metres, so nothing can become eligible inside one cell that was not eligible at
    /// the edge of it.
    private func lookForAMemory() {
        guard wantsNudges, nudge == nil else { return }

        let candidates = memories.map { memory in
            Resurface.Candidate(
                id: memory.id,
                metres: Geo.metres(from: here, to: (memory.latitude, memory.longitude)),
                happenedOn: memory.happenedOn,
                lastSurfaced: memory.lastSurfaced
            )
        }

        guard let picked = Resurface.pick(from: candidates),
              let memory = memories.first(where: { $0.id == picked.id })
        else { return }

        // Stamped when it is shown, not when it is opened. The cooldown is about how often
        // this is allowed to interrupt, and it interrupted whether or not you did anything
        // about it.
        memory.lastSurfaced = .now
        try? context.save()

        withAnimation(Motion.surface) { nudge = memory }
    }

    /// Memories close enough to be worth drawing. The same radius that decides whether one
    /// resurfaces, so what you see on the map and what taps you on the shoulder agree.
    private var visibleMemories: [MemoryRecord] {
        MemoryRecord.near(
            latitude: here.lat,
            longitude: here.lon,
            in: memories,
            radius: Geo.memoryRadiusMetres * 8   // wider than the surface radius, so you can see one coming
        )
    }

    var body: some View {
        ZStack {
            MapLibreMap(
                coordinate: location.coordinateOrFallback,
                bearing: camera.bearing,
                pitch: camera.pitch,
                zoom: camera.zoom,
                bears: bears,
                radar: RadarState(
                    centre: location.coordinateOrFallback,
                    discoverable: state.discoverable
                ),
                projection: projection
            )
            .ignoresSafeArea()

            // Look around: drag horizontally to turn, vertically to raise or lower the view.
            //
            // This is a transparent SwiftUI layer rather than a gesture on the map view.
            // MLNMapView keeps its own recognisers attached even with every interaction
            // switched off, and they can swallow the touch before SwiftUI sees it — a
            // gesture that silently never fires is the worst kind to debug. A plain
            // Color.clear always receives it.
            //
            // It sits below the pins and the chrome in the stack, so those still take taps.
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { camera.drag($0.translation) }
                        .onEnded { _ in camera.endDrag() }
                )
                // Pinch to zoom. Simultaneous rather than exclusive, because the two
                // gestures genuinely co-occur — fingers rarely pinch without also sliding a
                // little, and making them exclusive means whichever recogniser wins first
                // locks the other out for the rest of the gesture.
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { camera.pinch($0.magnification) }
                        .onEnded { _ in camera.endPinch() }
                )
                .ignoresSafeArea()
            // Above the map, below everything printed on it. The haze goes first: it is part
            // of the ground, and the sky has to be able to sit on top of where it ends.
            Haze()
                .ignoresSafeArea()
            SkyBand(latitude: here.lat, longitude: here.lon, bearing: camera.bearing)

            memoryLayer
            PlayerPuck(
                level: state.level,
                progress: state.levelProgress,
                // Walks when you are walking. `course` is only published above a walking
                // threshold, so standing still is a genuine idle rather than a frozen
                // walk frame -- the same rule every other bear on the map is drawn by.
                phase: location.course == nil ? nil : walkPhase
            )

            VStack(spacing: 0) {
                topBar

                // Under the top bar rather than over the map's middle. It is an aside, and an
                // aside that lands on top of where you are standing is not an aside.
                if let nudge {
                    MemoryNudge(
                        memory: nudge,
                        onOpen: {
                            openMemory = nudge
                            withAnimation(Motion.surface) { self.nudge = nil }
                        },
                        onDismiss: { withAnimation(Motion.surface) { self.nudge = nil } }
                    )
                    .padding(.top, Space.tight)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: Space.step)
                NearbyRail(people: state.nearby, focused: $focusedNearby)
                    // The rail and the card answer the same question at different scales --
                    // who is around, versus who is here. When somebody is close enough to
                    // photograph, the specific answer wins and the list gets out of its way.
                    .opacity(revealed == nil ? 1 : 0)
                    .animation(.easeOut(duration: 0.18), value: revealed?.id)
                Spacer(minLength: Space.step)
                bottomBar
            }
            .padding(.horizontal, Space.inset)
            .padding(.bottom, Space.margin)
            .opacity(catchMenu || deckMenu ? 0 : 1)

            // Above the chrome, because it is the one thing on the map you are meant to act
            // on the moment it appears.
            revealLayer
                .opacity(catchMenu || deckMenu ? 0 : 1)

            if deckMenu {
                ListMenu(
                    // Widest first. The pills are sized by their labels, so ordering them
                    // long to short gives the stack one clean diagonal edge instead of a
                    // ragged one, and puts the close button at the narrow end.
                    //
                    // The visibility toggle is deliberately not here. It already lives in the
                    // top-right pill on the map, where it belongs — it is a state you are in,
                    // not an errand you run, and having it in two places made it read as a
                    // fourth destination.
                    //
                    // Profile is gone for the same reason: tapping the bear in the bar opens
                    // it, so a second door to it was a menu row spent on nothing. Its slot
                    // went to the other half of "Add someone" — the handle you hand over.
                    options: [
                        RadialOption(icon: "person.badge.plus", label: "Add someone") { showAddFriend = true },
                        RadialOption(icon: "at", label: "My handle") { showMyHandle = true },
                        RadialOption(icon: "square.grid.2x2.fill", label: "Album") { showAlbum = true },
                        RadialOption(icon: "globe", label: "Globe") { showGlobe = true },
                    ],
                    onClose: { deckMenu = false }
                )
            }

            // The photo going where photos go. Without it a catch ends with a sheet closing
            // and nothing to show for it, and the album becomes a place things are simply
            // discovered in later rather than sent to.
            if let flying {
                GeometryReader { geo in
                    Image(uiImage: flying)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: flown ? 44 : 210,
                            height: flown ? 44 : 260
                        )
                        .clipShape(RoundedRectangle(
                            cornerRadius: flown ? Radius.control : Radius.card,
                            style: .continuous
                        ))
                        .elevated(.card)
                        .rotationEffect(.degrees(flown ? -12 : 0))
                        .opacity(flown ? 0 : 1)
                        .position(
                            x: flown ? Space.inset + 29 : geo.size.width / 2,
                            y: flown ? geo.size.height - Space.margin - 38 : geo.size.height / 2
                        )
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }

            if catchMenu {
                RadialMenu(
                    title: state.canCatch ? "Catch someone" : "Nobody nearby yet",
                    options: [
                        RadialOption(icon: "person.badge.plus", label: "By handle") {
                            showAddFriend = true
                        },
                        // The camera is the middle and the largest, because it is what people
                        // came for. Everything else on this menu is a fallback.
                        RadialOption(icon: "camera.fill", label: "Take a picture", isPrimary: true) {
                            catchPulse += 1
                            showCatch = true
                        },
                    ],
                    onClose: { catchMenu = false }
                )
            }
        }
        .background(MapStyle.ground(for: accent))
        // Cell, not coordinate. A fix lands every 25 metres and the radius is 150, so nothing
        // can become eligible inside one cell that was not already eligible at its edge --
        // running the whole candidate list six times a block would be work for nothing.
        //
        // `initial` matters more than it looks: without it the only trigger is crossing a cell
        // boundary, so opening the app while standing on the spot where something happened --
        // which is most of the times this should fire -- said nothing at all until you walked
        // a block and came back.
        .onChange(of: cell, initial: true) { _, _ in lookForAMemory() }
        // And again when the store finishes loading, because on a cold launch the query is
        // still empty at the moment the first check runs. Catching somebody also lands here
        // and is deliberately harmless: a memory made seconds ago is inside `minimumAge` and
        // cannot be picked.
        .onChange(of: memories.count) { _, _ in lookForAMemory() }
        .task(id: nudge?.id) {
            // Takes itself away. A strip that only leaves when you deal with it stops being an
            // aside and becomes something you have to deal with.
            guard nudge != nil else { return }
            try? await Task.sleep(for: Self.nudgeLifetime)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.surface) { nudge = nil }
        }
        #if DEBUG
        // Re-place the demo people once a real fix lands, not on appear. On appear the
        // coordinate is still the fallback, so seeding there put them in Dolores Park however
        // the simulator was pointed -- and then never moved them.
        .onChange(of: here.lat) { _, _ in
            DemoSeed.populate(state, around: location.coordinateOrFallback)
        }
        #endif
        .task {
            // Ten a second, not sixty. A walk cycle wants eight to twelve frames a second
            // anyway, and the slight stagger of a low frame rate suits a drawn character
            // better than smooth interpolation would.
            while !Task.isCancelled {
                if !Motion.reduceMotion { walkPhase += 1 }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        .task {
            // Deliberately does NOT request permission. The map is built underneath
            // onboarding from the first frame, so asking here fires the system alert before
            // the screen that explains why — which is both worse to read and the exact thing
            // Apple rejects for. Onboarding owns the request; this only starts updates if
            // permission is already there.
            location.start()
            #if DEBUG
            switch DemoSeed.opens {
            case "album": showAlbum = true
            case "profile": showProfile = true
            case "catch": catchMenu = true
            case "deck": deckMenu = true
            case "globe": showGlobe = true
            default: break
            }
            #endif
        }
        .onChange(of: catches.count, initial: true) { _, _ in
            state.recompute(from: catches)
        }
        .onChange(of: location.course) { _, course in
            camera.follow(course: course)
        }
        .sheet(item: $openMemory) { memory in
            MemorySheet(memory: memory) { state.award(.memoryRevisited) }
                .presentationDetents([.height(560)])
                .presentationBackground(Ink.ground)
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showCatch) {
            CatchSheet(
                cell: cell,
                placeLabel: location.placeLabel,
                coordinate: here,
                onSaved: { image in
                    guard let image else { return }
                    // Held until the sheet is actually gone. Starting the flight underneath a
                    // dismissing sheet means the first third of it happens behind a panel.
                    Task {
                        try? await Task.sleep(for: .milliseconds(320))
                        flown = false
                        flying = image
                        withAnimation(.spring(duration: 0.72, bounce: 0.18)) { flown = true }
                        try? await Task.sleep(for: .milliseconds(760))
                        flying = nil
                    }
                }
            )
                .presentationDetents([.large])
                .presentationCornerRadius(30)
                .onDisappear { state.award(.caught) }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet(cell: cell, placeLabel: location.placeLabel, nearby: state.nearby)
                // Taller than it was: the sheet now leads with everyone standing around you
                // rather than with an empty text field.
                .presentationDetents([.large])
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showMyHandle) {
            MyHandleSheet()
                .presentationDetents([.height(470)])
                .presentationCornerRadius(30)
        }
        .fullScreenCover(isPresented: $showGlobe) {
            GlobeScreen()
        }
        .sheet(isPresented: $showAlbum) {
            AlbumScreen()
        }
        .fullScreenCover(isPresented: $showProfile) {
            ProfileScreen(state: state)
        }
    }

    // MARK: Layers

    /// Memories are placed by their real offset from where you are standing, in metres,
    /// scaled to the screen. That is what makes the placeholder map behave like a map: walk
    /// a block and the pins move correctly, even before MapLibre exists.
    /// Memories, standing where they happened.
    ///
    /// Placed by asking the map where the coordinate is, not by converting metres to points at
    /// a fixed rate. The fixed rate was 3.4 metres per point and it was wrong in three
    /// independent ways at once: it ignored zoom, so every pin sat at whatever distance 3.4
    /// happened to mean; it ignored bearing, so turning the map left the pins facing north;
    /// and it ignored pitch, so nothing was on the ground plane the rest of the screen is
    /// drawn on. At the zoom this map now opens at, a memory fifty metres away was landing
    /// fifteen points from the puck -- a pile of polaroids on top of the player.
    private var memoryLayer: some View {
        GeometryReader { geo in
            ForEach(visibleMemories) { memory in
                if let point = projection.point(
                    for: CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude)
                ), geo.frame(in: .local).insetBy(dx: -60, dy: -60).contains(point) {
                    MemoryBubble(memory: memory) { openMemory = memory }
                        // Anchored at its foot, like the bears, so a pin sits on the spot
                        // rather than hovering with the spot at its middle.
                        .position(x: point.x, y: point.y - 30)
                }
            }
        }
        // Same reason as the reveal card: the map ignores the safe area and this has to be
        // measured in the same space, and reading `tick` is what re-places these as the
        // camera moves.
        .ignoresSafeArea()
        .id(projection.tick)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            // Absent at zero rather than announcing it. A streak that can shame you is
            // precisely the mechanic this app declined to copy; "0 weeks" in the corner of
            // every screen is the shame with extra steps.
            if state.streakWeeks > 0 {
                FloatingPill {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(accent.signal)
                        Text("\(state.streakWeeks)")
                            .font(.custom(Typeface.bagel, size: 14))
                            .foregroundStyle(Ink.text)
                        Text(state.streakWeeks == 1 ? "week" : "weeks")
                            .font(.chinFootnote)
                            .foregroundStyle(Ink.textSoft)
                    }
                }
                .accessibilityLabel("\(state.streakWeeks) week streak")
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Discovery is a switch you flip when you go out, and it says so plainly.
            // Nothing about this state is ever hidden from the person it describes.
            Button {
                withAnimation(Motion.surface) { state.discoverable.toggle() }
            } label: {
                FloatingPill {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(state.discoverable ? Ink.jade : Ink.textFaint)
                            .frame(width: 8, height: 8)
                        Text(state.discoverable ? "Out" : "Hidden")
                            .font(.chinCallout)
                            .foregroundStyle(Ink.text)
                    }
                }
            }
            .buttonStyle(SquashButtonStyle())
            .accessibilityLabel(
                state.discoverable
                    ? "You are discoverable. Tap to hide."
                    : "You are hidden. Tap to become discoverable."
            )
        }
    }

    private var bottomBar: some View {
        HomeBar(
            level: state.level,
            progress: state.levelProgress,
            glanceTowards: glanceBearing,
            canCatch: state.canCatch,
            catchPulse: catchPulse,
            onProfile: {
                // Straight to the profile. A menu in front of your own profile is a step
                // that exists only to show the menu.
                showProfile = true
            },
            onCatch: { withAnimation(Motion.arrive) { catchMenu = true } },
            onCatchHold: {
                // Straight past the menu to the camera. The haptic fires at the moment it
                // commits, which is how a hidden shortcut gets discovered -- by feel, without
                // anyone having to be told it exists.
                catchPulse += 1
                showCatch = true
            },
            onDeck: { withAnimation(Motion.arrive) { deckMenu = true } }
        )
        .overlay(alignment: .topTrailing) {
            // The compass cannot be a fourth cell: it only exists once you have turned the
            // view, and a cell that appears and disappears breaks the bar into two different
            // shapes. So it floats above the end of the bar, next to the thing it undoes.
            if !camera.isFollowingCourse {
                Button { camera.recenter(course: location.course) } label: {
                    Image(systemName: "location.north.line.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent.signal)
                        .rotationEffect(.degrees(-camera.bearing))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(StickerCircleStyle(fill: Ink.groundRaised))
                .hitTarget()
                .accessibilityLabel("Face the way you are walking")
                .transition(.scale.combined(with: .opacity))
                .offset(y: -Space.section)
            }
        }
        .animation(Motion.surface, value: camera.isFollowingCourse)
    }
}

/// What a memory pin opens into.
///
/// One button. The whole feature exists to produce a message to a person you had stopped
/// thinking about, so anything else on this sheet is in the way.
struct MemorySheet: View {
    @Environment(\.accent) private var accent

    let memory: MemoryRecord
    var onReconnect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetShell {
        VStack(spacing: 0) {
            Group {
                if !memory.isDeveloped {
                    Developing(developsAt: memory.developsAt)
                } else if let image = PhotoStore.load(memory.photoFile) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Ink.groundSunk.overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 34))
                            .foregroundStyle(Ink.textFaint)
                    }
                }
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 20)

            Text(memory.agoDescription)
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
                .padding(.top, 18)

            Text("You and \(memory.friendHandle)")
                .font(.chinTitle)
                .foregroundStyle(Ink.text)
                .padding(.top, 4)

            Text(memory.placeLabel)
                .font(.chinHand)
                .foregroundStyle(Ink.textSoft)
                .padding(.top, 2)

            Spacer(minLength: 16)

            Button {
                memory.lastSurfaced = .now
                onReconnect()
                dismiss()
            } label: {
                Text("Reconnect")
                    .font(.chinShout)
                    .foregroundStyle(accent.onSignal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(accent.signal))
            }
            .buttonStyle(SquashButtonStyle())
        }
        .padding(.horizontal, Space.margin)
        }
    }
}
