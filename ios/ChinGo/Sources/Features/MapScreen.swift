import SwiftUI
import ChinGoDesign

/// The home screen: a world with things floating over it.
///
/// The architecture is deliberately the one Pokémon GO uses, because for a one-handed map
/// app it is simply correct — the map owns every pixel, the player sits fixed at the
/// centre, and all controls are small rounded objects detached from the edges. Everything
/// specific to Niantic (their basemap style, their pillars, their sphere) is not here.
struct MapScreen: View {
    @Bindable var state: MapState
    @State private var showMemory: MemoryPin?
    @State private var catchPulse = 0

    var body: some View {
        ZStack {
            MapSurface()

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
        .sheet(item: $showMemory) { pin in
            MemorySheet(pin: pin)
                .presentationDetents([.height(430)])
                .presentationBackground(Ink.ground)
                .presentationCornerRadius(30)
        }
    }

    // MARK: Layers

    private var memoryLayer: some View {
        GeometryReader { geo in
            ForEach(state.memories) { pin in
                MemoryBubble(pin: pin) { showMemory = pin }
                    .position(
                        x: geo.size.width * pin.x,
                        y: geo.size.height * pin.y
                    )
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            FloatingPill {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Ink.signal)
                    Text("\(state.streakWeeks)")
                        .font(.custom(Typeface.bagel, size: 14))
                        .foregroundStyle(Ink.text)
                    Text("weeks")
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.textSoft)
                }
            }
            .accessibilityLabel("\(state.streakWeeks) week streak")

            Spacer()

            // Discovery is a switch you flip when you go out, and it says so plainly.
            // Nothing about this state is ever hidden from the person it describes.
            Button {
                withAnimation(Motion.surface) { state.toggleDiscoverable() }
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
            .accessibilityLabel(state.discoverable ? "You are discoverable. Tap to hide." : "You are hidden. Tap to become discoverable.")
        }
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            FloatingOrb(action: {}) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Ink.textSoft)
            }
            .accessibilityLabel("Album")

            Spacer()

            VStack(spacing: 10) {
                if state.canCatch {
                    FloatingPill {
                        Text("\(state.nearby.count) nearby")
                            .font(.chinCallout)
                            .foregroundStyle(Ink.text)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                CatchButton(enabled: state.canCatch) {
                    catchPulse += 1
                }
                .rewardBeat(on: catchPulse)
            }

            Spacer()

            FloatingOrb(action: {}) {
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Ink.textSoft)
            }
            .accessibilityLabel("You")
        }
        .animation(Motion.surface, value: state.canCatch)
    }
}

/// What a memory pin opens into.
///
/// One button. The whole feature exists to produce a message to a person you had stopped
/// thinking about, so anything else on this sheet is in the way.
struct MemorySheet: View {
    let pin: MemoryPin

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Ink.groundSunk)
                .frame(height: 200)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 34))
                        .foregroundStyle(Ink.textFaint)
                }
                .padding(.top, 20)

            Text(pin.agoDescription)
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
                .padding(.top, 18)

            Text("You and \(pin.friendHandle)")
                .font(.chinTitle)
                .foregroundStyle(Ink.text)
                .padding(.top, 4)

            Text(pin.place)
                .font(.chinHand)
                .foregroundStyle(Ink.textSoft)
                .padding(.top, 2)

            Spacer(minLength: 16)

            Button {} label: {
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
