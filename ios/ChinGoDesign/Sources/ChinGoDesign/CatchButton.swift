import SwiftUI

/// The one loud control on the map.
///
/// Structurally this occupies the same place as Pokémon GO's centre button, because that
/// placement is simply correct for a one-handed map app: thumb-reachable, unmissable, and it
/// leaves the map unobstructed above it.
///
/// It is deliberately **not** a sphere. No red-over-white two-tone, no belt line, no centre
/// button — that silhouette is the single highest-risk asset anyone can draw in this
/// category. ChinGo's glyph is two rounded forms meeting: the moment two people are in the
/// same place, which is the entire game.
///
/// **Tap** opens the menu. **Hold** fills the button like a glass of water and fires the
/// camera when it reaches the top. The fill is not decoration — it is the only thing telling
/// you how long to keep holding, and it drains if you let go early so an abandoned hold
/// visibly costs nothing.
public struct CatchButton: View {
    private let enabled: Bool
    private let action: () -> Void
    private let longPress: (() -> Void)?

    @Environment(\.accent) private var accent

    @State private var pulse = false
    @State private var fill: CGFloat = 0
    @State private var wave: CGFloat = 0
    /// Bumped when a hold completes, so the haptic lands exactly then.
    @State private var holdCommitted = 0

    /// Long enough to be unmistakably deliberate, short enough that nobody wonders whether it
    /// is working. Also the exact duration the fill animates over, so the water reaching the
    /// top *is* the countdown rather than a decoration next to one.
    private static let holdDuration: Double = 1.05

    public init(
        enabled: Bool,
        action: @escaping () -> Void,
        longPress: (() -> Void)? = nil
    ) {
        self.enabled = enabled
        self.action = action
        self.longPress = longPress
    }

    public var body: some View {
        ZStack {
            // The halo only exists when there is someone to catch. A button that pulses
            // forever teaches people to ignore it.
            if enabled {
                Circle()
                    .stroke(accent.signal.opacity(0.30), lineWidth: 3)
                    .scaleEffect(pulse ? 1.28 : 1)
                    .opacity(pulse ? 0 : 1)
            }

            // Sticker, like everything else it now shares a bar with. The two soft shadows
            // this replaces -- one of them a coloured bloom -- were the last of the glassy
            // language left on the map, and the most Pokemon-GO-looking thing in the app.
            Circle()
                .fill(enabled ? accent.signal : Ink.groundSunk)
                .overlay(Circle().strokeBorder(Ink.text, lineWidth: 3))
                .compositingGroup()
                .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)

            // The water. Lighter than the button so the level is legible against it, and
            // clipped to the circle so it reads as filling the button rather than sitting on
            // top of it.
            LiquidFill(progress: fill, phase: wave)
                .fill(accent.onSignal.opacity(0.42))
                .clipShape(Circle())

            LinkGlyph()
                .fill(enabled ? accent.onSignal : Ink.textFaint, style: LinkGlyph.fillStyle)
                .frame(width: 26 * 1.66, height: 26)
        }
        .frame(width: 78, height: 78)
        .scaleEffect(fill > 0 ? 1 + fill * 0.06 : 1)
        .contentShape(Circle())
        .onTapGesture {
            guard enabled else { return }
            action()
        }
        .onLongPressGesture(
            minimumDuration: Self.holdDuration,
            maximumDistance: 40,
            perform: {
                guard enabled, let longPress else { return }
                holdCommitted += 1
                longPress()
            },
            onPressingChanged: { pressing in
                guard enabled else { return }
                if pressing {
                    // Linear, and exactly the hold duration: the water arriving at the top has
                    // to mean the shutter, or the gauge is lying.
                    withAnimation(.linear(duration: Self.holdDuration)) { fill = 1 }
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        wave = 1
                    }
                } else {
                    // Drains faster than it filled. Letting go should feel like nothing
                    // happened, not like undoing something.
                    withAnimation(.easeOut(duration: 0.28)) { fill = 0 }
                    wave = 0
                }
            }
        )
        .sensoryFeedback(.impact(weight: .heavy), trigger: holdCommitted)
        .disabled(!enabled)
        .onChange(of: holdCommitted) { _, _ in
            // The water empties once it has fired, or the button stays full behind whatever
            // it opened and is still full when you come back.
            withAnimation(.easeOut(duration: 0.35)) { fill = 0 }
        }
        .onAppear {
            guard !Motion.reduceMotion else { return }
            withAnimation(Motion.breathe) { pulse = true }
        }
        .accessibilityLabel(enabled ? "Catch" : "Nobody nearby yet")
        .accessibilityHint("Tap for options. Hold to open the camera.")
    }
}

/// Water rising in a round glass.
///
/// The surface is a sine wave whose amplitude falls away as the level approaches the top, so
/// it settles flat at the moment of firing instead of still sloshing. A wave that is still
/// moving when the shutter goes reads as the animation having been interrupted.
public struct LiquidFill: Shape {
    public var progress: CGFloat
    public var phase: CGFloat

    public init(progress: CGFloat, phase: CGFloat) {
        self.progress = progress
        self.phase = phase
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0.001 else { return path }

        let level = rect.maxY - rect.height * progress
        // Tallest early, gone by the top.
        let amplitude = rect.height * 0.045 * (1 - progress)
        let waves = 1.6

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: level))

        var x = rect.minX
        while x <= rect.maxX {
            let ratio = (x - rect.minX) / max(rect.width, 1)
            let y = level + sin((ratio * waves + phase) * 2 * .pi) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Two blunt rounded forms meeting, with the shared area knocked out — the mark for
/// "two people, same place".
///
/// Every terminal is rounded and neither half is a circle, so at 32×32 it reads as a link
/// rather than as a ball. The knockout is what keeps it legible: two solid overlapping shapes
/// merge into one blob at small sizes, which is exactly the silhouette this app must not have.
public struct LinkGlyph: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        let side = rect.height
        let overlap = side * 0.34
        let corner = side * 0.42

        let left = CGRect(x: rect.minX, y: rect.minY, width: side, height: side)
        let right = CGRect(x: rect.minX + side - overlap, y: rect.minY, width: side, height: side)

        p.addRoundedRect(in: left, cornerSize: CGSize(width: corner, height: corner), style: .continuous)
        p.addRoundedRect(in: right, cornerSize: CGSize(width: corner, height: corner), style: .continuous)
        return p
    }

    /// Even-odd is what produces the knockout where the two forms cross.
    public static let fillStyle = FillStyle(eoFill: true)
}
