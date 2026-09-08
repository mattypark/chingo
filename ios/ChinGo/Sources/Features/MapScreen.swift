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
    @State private var showCatch = false
    @State private var showAlbum = false
    @State private var showGlobe = false
    @State private var showStreak = false
    /// Bumped by `-tour globe` to make the globe leave the way a thumb would. Always zero
    /// outside a debug run.
    @State private var globeLeaves = 0
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
    /// How far through being drawn the reveal card is. Driven by hand rather than by a
    /// transition, because a transition can only fade or move a finished view -- and the whole
    /// point here is that the card is not finished until it has been drawn.
    @State private var cardDrawn: Drawn = .blank
    /// Bumped when somebody new comes into range, so the haptic fires on the crossing rather
    /// than on every frame they stay there.
    @State private var reveals = 0
    /// The memory currently being mentioned, if any. See `MemoryNudge`.
    @State private var nudge: MemoryRecord?
    /// Bumped per memory surfaced, to hang the haptic on. A counter rather than the memory's
    /// own id, because that also changes on the way out and would buzz on dismissal.
    @State private var nudges = 0
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

    /// How much of the right edge the nearby rail owns. Nothing on the map is drawn into it.
    private static let railColumn: CGFloat = 150
    /// The furthest a memory pin will step aside to stay out of that column. About its own
    /// width -- far enough to clear a graze, not far enough to leave a stem pointing at the
    /// horizon.
    private static let railNudge: CGFloat = 46

    /// How far from a bear's middle a tap still counts as landing on it. Wider than the
    /// character, because at this zoom a bear is about 44 points tall and a thumb is not
    /// precise -- and the only thing a near miss can do is open the wrong card, which is one
    /// tap to undo.
    private static let tapReach: CGFloat = 46

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
    /// Who the card is open on, and it is only ever somebody you tapped.
    ///
    /// It used to open itself on whoever was nearest inside `interactionMetres`. That is one
    /// step too eager: on a map whose whole job is to show you a street with people standing
    /// on it, somebody is nearly always inside that radius, so a card was permanently parked
    /// over the middle of the screen covering the thing it was pointing at. A card that is
    /// always there is not a reveal, it is furniture.
    ///
    /// Proximity still decides who *can* be opened -- tapping a bear too far away does
    /// nothing, and the ring on the ground is what says how far that is. Coming into range is
    /// announced by the radar and by the rail down the right, both of which say "somebody is
    /// here" without taking the screen to do it.
    ///
    /// Still released at `releaseMetres` rather than at `interactionMetres`: a card you opened
    /// should not snap shut because GPS drifted five metres while you were reading it.
    private var revealed: NearbyPerson? {
        guard let held = revealedID,
              let still = state.nearby.first(where: { $0.id == held }),
              Double(still.approxMetres) <= Radar.releaseMetres
        else { return nil }
        return still
    }

    /// Rebuild XP and both streaks from what happened, plus the two things that leave no
    /// record behind. Cheap: a fold over the catch list and two walks over a set.
    /// The stored record, if there is one yet.
    private var identity: MeRecord? { me.first }

    private func refreshProgress() {
        state.recompute(
            from: catches,
            bonusXP: identity?.awardedXP ?? 0,
            frozenDays: identity?.frozenDays ?? []
        )
    }

    /// Put the home-screen icon back in step with how long it has been, and stamp today.
    ///
    /// Runs off the same pass that rebuilds progress, because that is the first moment both
    /// the day ordinal and the stored record are available together. Stamping *after* the
    /// reconcile matters: the check needs the day of the previous launch, and writing today
    /// first would make every launch look like it happened today.
    private func markActive() {
        guard let identity, state.today > 0 else { return }

        LapseIcon.reconcile(
            lastActiveDay: identity.lastActiveDay,
            today: state.today,
            chosen: identity.alternateIcon,
            wantsLapseIcon: identity.wantsLapseIcon
        )

        guard identity.lastActiveDay != state.today else { return }
        identity.lastActiveDay = state.today
        try? context.save()
    }

    /// Revisiting a memory earns XP that no `CatchRecord` will ever account for, so it is
    /// written to the one place that survives a recompute.
    private func reconnected() {
        guard let identity = me.first else { return }
        identity.awardedXP += XPEvent.memoryRevisited.amount
        try? context.save()
    }

    /// Whether tapping this person opens their card. The ring on the ground is this line.
    private func canReveal(_ person: NearbyPerson) -> Bool {
        Double(person.approxMetres) <= Radar.interactionMetres
    }

    /// Open the card on whichever bear was tapped, or close it if that was the street.
    ///
    /// Measured against the middle of each bear rather than the coordinate it stands on: a
    /// bear is anchored at its feet, so hit-testing the coordinate means the tappable spot is
    /// the ground under it and the character itself is not the target.
    private func reveal(nearest point: CGPoint) {
        let hit = state.nearby
            .compactMap { person -> (person: NearbyPerson, distance: CGFloat)? in
                guard canReveal(person), let foot = projection.point(for: person.coordinate) else { return nil }
                let body = CGPoint(x: foot.x, y: foot.y - Self.bearHeight / 2)
                let reach = hypot(body.x - point.x, body.y - point.y)
                return reach <= Self.tapReach ? (person, reach) : nil
            }
            .min { $0.distance < $1.distance }

        guard hit?.person.id != revealedID else { return }
        guard let person = hit?.person else { return erase() }
        open(person)
    }

    /// Draw the card on for somebody. Split from the hit test so `-tour reveal` can reach it:
    /// simctl can launch a screen but cannot tap a bear on it, and a build-on animation that
    /// only ever plays on a real tap is one nobody can look at from here.
    private func open(_ person: NearbyPerson) {
        reveals += 1
        // Blank first, so a tap that moves the card from one bear to another redraws it there
        // rather than sliding a finished card across the street.
        cardDrawn = .blank
        revealedID = person.id

        guard !Motion.reduceMotion else { return cardDrawn = .complete }

        Task { @MainActor in
            // One frame later, and that is not a fudge. Inserting a view and animating it in
            // the same transaction gives the animator no previous state to interpolate from,
            // so the card arrives finished. Letting it be laid out blank first is what gives
            // the draw somewhere to start.
            try? await Task.sleep(for: .milliseconds(20))
            withAnimation(Motion.draw) { cardDrawn = .complete }
        }
    }

    /// The card leaves the way it arrived, backwards: the words go, the colour drains, the
    /// outline retracts and the stem pulls back up. Faster than it was drawn, like every other
    /// exit in the app.
    private func erase() {
        guard revealedID != nil else { return }
        withAnimation(Motion.erase) { cardDrawn = .blank }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(340))
            // Only if nothing has been tapped in the meantime, or this clears a card that was
            // drawn while the erase was still running.
            if cardDrawn.isBlank { revealedID = nil }
        }
    }

    /// The card, over the bear it belongs to.
    private var revealLayer: some View {
        GeometryReader { geo in
            // Reading `tick` is what re-places the card as the camera moves.
            //
            // Read as a value rather than hung on the layer as an `.id`, which is what it used
            // to be. `MapProjection` is `@Observable`, so the read alone is enough to re-run
            // this -- and the `.id` was doing something far worse than being redundant. It
            // advances on *every rendered frame*, so it gave the card a new identity sixty
            // times a second, and a view whose identity keeps changing cannot animate: the
            // card snapped to finished instead of being drawn. `GlobeScreen.tokens` carries
            // the same warning for the same reason.
            let _ = projection.tick

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
                    drawn: cardDrawn,
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
        // `.pick` now, not `.arrive`. This card is opened by a thumb landing on a bear, which
        // is exactly what `.pick` is for -- `.arrive` was right while the card opened itself
        // at whoever walked into range, and that is no longer how it works.
        .feedback(.pick, on: reveals)
        // Clears the card when the person it belongs to walks out of range, and only then.
        .onChange(of: revealed?.id) { _, next in
            if next == nil { revealedID = nil }
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

        nudges += 1
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
                // Tap a bear to open their card; tap the street to put it away. Hit-tested
                // here rather than on the map, because MapLibre's own recognisers are all
                // switched off and its symbol layers cannot report a tap without them.
                .onTapGesture { point in reveal(nearest: point) }
                .ignoresSafeArea()
            // Above the map, below everything printed on it. The haze goes first: it is part
            // of the ground, and the sky has to be able to sit on top of where it ends.
            Haze(pitch: camera.pitch)
                .ignoresSafeArea()
            SkyBand(
                latitude: here.lat,
                longitude: here.lon,
                bearing: camera.bearing,
                pitch: camera.pitch
            )

            RadarPulse(
                centre: location.coordinateOrFallback,
                projection: projection,
                discoverable: state.discoverable
            )
            .ignoresSafeArea()

            memoryLayer
            PlayerPuck(
                level: state.level,
                // Walks when you are walking. `course` is only published above a walking
                // threshold, so standing still is a genuine idle rather than a frozen
                // walk frame -- the same rule every other bear on the map is drawn by.
                phase: location.course == nil ? nil : walkPhase,
                // The direction you are actually walking, held while you stand still so the
                // bear does not spin to face the phone every time the camera turns.
                heading: location.course,
                cameraBearing: camera.bearing
            )

            VStack(spacing: 0) {
                // Each piece leaves on its own beat. This stack used to share one `.opacity`,
                // which is why the whole thing could only ever fade as a single plane.
                topBar.pops(hidden: showGlobe, rank: 0)

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

                // Equal gaps above and below, so the rail sits on the vertical middle of the
                // right edge. That is where GOAT's level list sits and it is the arrangement
                // this was lifted from; it only ever moved because the reveal card used to
                // open itself over the top of it, and the card is opened by a tap now.
                Spacer(minLength: Space.step)
                // Always. The rail used to blank itself whenever somebody came close enough
                // to photograph, on the reasoning that the card and the list answer the same
                // question and the specific answer should win.
                //
                // That was wrong about which question the rail answers. The card says "this
                // person, now"; the rail is the standing answer to "who is out" -- the one
                // thing the map cannot say on its own, and the reason the right edge exists.
                // In practice somebody is nearly always inside the reveal radius, so the list
                // was hidden almost all the time and the screen read as having no names in it
                // at all.
                NearbyRail(people: state.nearby, focused: $focusedNearby)
                    .pops(hidden: showGlobe, rank: 1)
                Spacer(minLength: Space.step)
                bottomBar.pops(hidden: showGlobe, rank: 2)
            }
            .padding(.horizontal, Space.inset)
            .padding(.bottom, Space.margin)
            .opacity(catchMenu ? 0 : 1)

            // Above the chrome, because it is the one thing on the map you are meant to act
            // on the moment it appears.
            revealLayer
                .opacity(catchMenu ? 0 : 1)

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

            // The globe, in the map's stack rather than over it in a presentation.
            //
            // Built only while it is open, so MapKit and MapLibre are not both running a
            // camera when nobody is looking at one of them. `Ink.ground` underneath it because
            // the globe's own map fades in, and without an opaque floor the first frames of
            // that fade are two maps at once.
            if showGlobe {
                GlobeScreen(onClose: { showGlobe = false }, leaveOn: globeLeaves)
                    .background(Ink.ground.ignoresSafeArea())
                    .zIndex(1)
            }

            if catchMenu {
                RadialMenu(
                    title: state.canCatch ? "Catch someone" : "Nobody nearby yet",
                    // Everything you might do about a person, on the button your thumb is
                    // already on. This absorbed the deck menu, which was a second door in the
                    // opposite corner holding the same errands -- adding somebody, handing
                    // over your handle, looking at what you caught. They are all one subject,
                    // and having them in two places made neither of them the answer.
                    //
                    // The visibility toggle is still deliberately not here. It lives in the
                    // top-right pill, because it is a state you are in rather than an errand
                    // you run. Profile is not here either: tapping the bear opens it.
                    options: [
                        RadialOption(icon: "square.grid.2x2.fill", label: "Album") {
                            showAlbum = true
                        },
                        RadialOption(icon: "at", label: "My handle") {
                            showMyHandle = true
                        },
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
        // `.arrive` is the case whose own doc comment names "a memory surfacing", and this is
        // the path it was written for.
        .feedback(.arrive, on: nudges)
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
            case "profile", "edit": showProfile = true
            case "catch": catchMenu = true
            case "globe": showGlobe = true
            case "streak": showStreak = true
            default: break
            }

            if DemoSeed.tour == "rail" {
                // Steps the focus down the rail, which is the only way to see the face hand
                // itself from one name to the next -- there is no scrub gesture from here.
                for step in 1...3 {
                    try? await Task.sleep(for: .milliseconds(1400))
                    withAnimation(Motion.tap) { focusedNearby = step }
                }
            }

            if DemoSeed.tour == "reveal" {
                try? await Task.sleep(for: .milliseconds(1500))
                if let somebody = state.nearby.first(where: canReveal) { open(somebody) }
                try? await Task.sleep(for: .milliseconds(2200))
                erase()
            }

            if DemoSeed.tour == "globe" {
                try? await Task.sleep(for: .milliseconds(1600))
                showGlobe = true
                try? await Task.sleep(for: .milliseconds(2400))
                // Through the screen's own way out rather than by flipping the flag, so what
                // gets filmed is the exit a thumb would produce.
                globeLeaves += 1
            }
            #endif
        }
        .onChange(of: catches.count, initial: true) { _, _ in
            refreshProgress()
            markActive()
        }
        // Freezes and the bonus are stored rather than derived, so a change to either has to
        // be pushed in -- the catch list has not moved and would not re-run the line above.
        .onChange(of: me.first?.frozenDays) { _, _ in refreshProgress() }
        .onChange(of: me.first?.awardedXP) { _, _ in refreshProgress() }
        .onChange(of: location.course) { _, course in
            camera.follow(course: course)
        }
        .sheet(item: $openMemory) { memory in
            MemorySheet(memory: memory) { reconnected() }
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
                // No award here. The `CatchRecord` the sheet just wrote is what earns the XP,
                // and `recompute` counts it -- awarding again on the way out double-counted it
                // and the next recompute silently deleted both.

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
        .sheet(isPresented: $showStreak) {
            StreakSheet(state: state)
                .presentationDetents([.height(470)])
                .presentationBackground(Ink.ground)
                .presentationCornerRadius(30)
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
                    // Nudged out from under the nearby rail, and only that far.
                    //
                    // The rail is a fixed column of names hard against the right edge, and a
                    // polaroid landing inside it covers whichever name it lands on -- which
                    // is the one the rail is focused on more often than chance, because both
                    // things cluster around the middle of the screen. Moving the card and
                    // leaving the stem pointing at the true spot keeps the memory where it
                    // happened; only the picture of it steps aside.
                    let clear = geo.size.width - Self.railColumn - MemoryBubble.width / 2
                    let x = min(point.x, clear)

                    // Nudged only so far. Clamping without a limit turned the stem into a
                    // wire reaching a third of the way across the screen for any memory that
                    // happened to be well inside the rail's column -- which reads as the
                    // polaroid being tethered to something rather than standing on it. Past
                    // the limit the picture is simply not drawn: the memory is still there,
                    // still resurfaces, and walking a few steps brings it back on screen.
                    if point.x - x <= Self.railNudge {
                        MemoryBubble(memory: memory, stemOffset: point.x - x) { openMemory = memory }
                            // Anchored at its foot, like the bears, so a pin sits on the spot
                            // rather than hovering with the spot at its middle.
                            .position(x: x, y: point.y - 30)
                    }
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
            // Days now, not weeks. The comment that used to sit here said a streak which can
            // shame you is precisely the mechanic this app declined to copy -- and that is
            // still the rule, it is just no longer an argument against counting days. See
            // `ChinGoEngine.Streak`, where the whole reversal is written down.
            //
            // What survives from it is this: absent at zero rather than announcing it. "0
            // days" in the corner of every screen is the shame with extra steps, and it is the
            // display that does the shaming rather than the unit.
            //
            // It is a button now. The one thing you can do about a streak -- spend a repair on
            // it -- has to be reachable from the only place the streak is ever mentioned.
            if state.streakDays > 0 || !state.repairableDays.isEmpty {
                Button { showStreak = true } label: {
                    FloatingPill {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12, weight: .bold))
                                // Grey when the run is broken and only a repair would bring it
                                // back. The pill is still there because there is something to
                                // do, not because you are doing well.
                                .foregroundStyle(state.streakDays > 0 ? accent.signal : Ink.textFaint)

                            if state.streakDays > 0 {
                                Text("\(state.streakDays)")
                                    .font(.custom(Typeface.bagel, size: 14))
                                    .foregroundStyle(Ink.text)
                                    .contentTransition(.numericText())
                                Text(state.streakDays == 1 ? "day" : "days")
                                    .font(.chinFootnote)
                                    .foregroundStyle(Ink.textSoft)
                            } else {
                                // Never "0 days". A zero in the corner of every screen is the
                                // shame this app declined to copy, and it is the *display*
                                // that does the shaming rather than the number -- so when
                                // there is nothing to count, the pill asks instead of scoring.
                                Text("Keep it?")
                                    .font(.chinCallout)
                                    .foregroundStyle(Ink.text)
                            }
                        }
                    }
                }
                .buttonStyle(SquashButtonStyle())
                .accessibilityLabel(
                    state.streakDays == 0
                        ? "Your streak can still be repaired. Tap to look after it."
                        : state.streakDays == 1
                            ? "1 day streak. Tap to look after it."
                            : "\(state.streakDays) day streak. Tap to look after it."
                )
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
            daysSinceMeetup: state.daysSinceMeetup,
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
            onGlobe: { showGlobe = true }
        )
        .overlay(alignment: .topTrailing) {
            // Neither of these can be a fourth cell in the bar. The compass only exists once
            // you have turned the view, and a cell that appears and disappears breaks the bar
            // into two different shapes; the globe is a place you go rather than a thing you
            // do here. So they stack above the end of the bar instead.
            // Only the compass floats here now. The globe moved into the bar, and two doors
            // to the same place a thumb's width apart is one more than there should be.
            if !camera.isFollowingCourse {
                CompassRose(bearing: camera.bearing) {
                    camera.recenter(course: location.course)
                }
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
