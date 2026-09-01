import SwiftUI

/// The one loud control on the map.
///
/// Structurally this occupies the same place as Pokémon GO's centre button, because that
/// placement is simply correct for a one-handed map app: thumb-reachable, unmissable, and
/// it leaves the map unobstructed above it.
///
/// It is deliberately **not** a sphere. No red-over-white two-tone, no belt line, no
/// centre button — that silhouette is the single highest-risk asset anyone can draw in
/// this category. ChinGo's glyph is two rounded forms meeting: the moment two people are
/// in the same place, which is the entire game.
public struct CatchButton: View {
    private let enabled: Bool
    private let action: () -> Void

    @State private var pulse = false

    public init(enabled: Bool, action: @escaping () -> Void) {
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                // The halo only exists when there is actually someone to catch. An idle
                // button that pulses forever teaches people to ignore it.
                if enabled {
                    Circle()
                        .stroke(Ink.signal.opacity(0.30), lineWidth: 3)
                        .scaleEffect(pulse ? 1.28 : 1)
                        .opacity(pulse ? 0 : 1)
                }

                Circle()
                    .fill(enabled ? Ink.signal : Ink.groundSunk)
                    .shadow(color: enabled ? Ink.signalDeep.opacity(0.35) : .clear, radius: 14, y: 6)
                    .shadow(color: Ink.shade, radius: 10, y: 4)

                LinkGlyph()
                    .fill(enabled ? Ink.onSignal : Ink.textFaint, style: LinkGlyph.fillStyle)
                    .frame(width: 26 * 1.66, height: 26)
            }
            .frame(width: 78, height: 78)
        }
        .buttonStyle(SquashButtonStyle())
        .disabled(!enabled)
        .onAppear {
            guard !Motion.reduceMotion else { return }
            withAnimation(Motion.breathe) { pulse = true }
        }
        .accessibilityLabel(enabled ? "Catch" : "Nobody nearby yet")
    }
}

/// Two blunt rounded forms meeting, with the shared area knocked out — the mark for
/// "two people, same place".
///
/// Every terminal is rounded and neither half is a circle, so at 32×32 it reads as a link
/// rather than as a ball. The knockout is what keeps it legible: two solid overlapping
/// shapes merge into one blob at small sizes, which is exactly the silhouette this app
/// must not have.
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
