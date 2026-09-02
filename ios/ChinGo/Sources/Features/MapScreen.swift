import SwiftUI
import SwiftData
import ChinGoDesign
import ChinGoEngine

/// The home screen: a world with things floating over it.
///
/// The architecture deliberately follows the one Pokémon GO uses, because for a one-handed
/// map app it is correct — the map owns every pixel, the player is fixed at the centre, and
/// controls are small rounded objects detached from the edges. Everything specific to
/// Niantic is absent: no sphere, no aim ring, no gym pillars, no basemap of theirs.
struct MapScreen: View {
    @Bindable var state: MapState
    @Environment(\.modelContext) private var context
    @Query private var memories: [MemoryRecord]
    @Query private var catches: [CatchRecord]

    let location: LocationService

    @State private var openMemory: MemoryRecord?
    @State private var showCatch = false
    @State private var showAlbum = false
    @State private var showAddFriend = false
    @State private var catchPulse = 0

    private var here: (lat: Double, lon: Double) {
        let c = location.coordinateOrFallback
        return (c.latitude, c.longitude)
    }

    private var cell: String {
        GeoCell(latitude: here.lat, longitude: here.lon).id
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
                course: location.course
            )
            .ignoresSafeArea()
            memoryLayer
            PlayerPuck(level: state.level, progress: state.levelProgress)

            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 26)
        }
        .background(Ink.mapLand)
        .task {
            location.requestPermission()
            location.start()
            #if DEBUG
            if DemoSeed.opensAlbum { showAlbum = true }
            #endif
        }
        .onChange(of: catches.count, initial: true) { _, _ in
            state.recompute(from: catches)
        }
        .sheet(item: $openMemory) { memory in
            MemorySheet(memory: memory) { state.award(.memoryRevisited) }
                .presentationDetents([.height(470)])
                .presentationBackground(Ink.ground)
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showCatch) {
            CatchSheet(cell: cell, placeLabel: location.placeLabel, coordinate: here)
                .presentationDetents([.large])
                .presentationCornerRadius(30)
                .onDisappear { state.award(.caught) }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet(cell: cell, placeLabel: location.placeLabel)
                .presentationDetents([.height(400)])
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showAlbum) {
            AlbumScreen()
        }
    }

    // MARK: Layers

    /// Memories are placed by their real offset from where you are standing, in metres,
    /// scaled to the screen. That is what makes the placeholder map behave like a map: walk
    /// a block and the pins move correctly, even before MapLibre exists.
    private var memoryLayer: some View {
        GeometryReader { geo in
            let metresPerPoint = 3.4
            ForEach(visibleMemories) { memory in
                let dx = Geo.metres(from: here, to: (here.lat, memory.longitude))
                    * (memory.longitude < here.lon ? -1 : 1)
                let dy = Geo.metres(from: here, to: (memory.latitude, here.lon))
                    * (memory.latitude < here.lat ? 1 : -1)

                MemoryBubble(memory: memory) { openMemory = memory }
                    .position(
                        x: geo.size.width / 2 + dx / metresPerPoint,
                        y: geo.size.height / 2 + dy / metresPerPoint
                    )
            }
        }
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
                            .foregroundStyle(Ink.signal)
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
        HStack(alignment: .bottom) {
            FloatingOrb(action: { showAlbum = true }) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Ink.textSoft)
            }
            .accessibilityLabel("Album")

            Spacer()

            VStack(spacing: 10) {
                if let place = location.placeLabel {
                    FloatingPill {
                        Text(place)
                            .font(.chinCallout)
                            .foregroundStyle(Ink.text)
                            .lineLimit(1)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                CatchButton(enabled: state.canCatch) {
                    catchPulse += 1
                    showCatch = true
                }
                .rewardBeat(on: catchPulse)
            }

            Spacer()

            FloatingOrb(action: { showAddFriend = true }) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Ink.textSoft)
            }
            .accessibilityLabel("Add someone by handle")
        }
        .animation(Motion.surface, value: location.placeLabel)
    }
}

/// What a memory pin opens into.
///
/// One button. The whole feature exists to produce a message to a person you had stopped
/// thinking about, so anything else on this sheet is in the way.
struct MemorySheet: View {
    let memory: MemoryRecord
    var onReconnect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let image = PhotoStore.load(memory.photoFile) {
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
                    .foregroundStyle(Ink.onSignal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Ink.signal))
            }
            .buttonStyle(SquashButtonStyle())
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 22)
    }
}
