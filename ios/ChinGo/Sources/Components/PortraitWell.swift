import SwiftUI
import ChinGoDesign

/// Your face, or your bear.
///
/// **The bear is not a placeholder.** It is what the map calls you, it is in the colour you
/// picked, and somebody who never adds a photo has a complete identity rather than a greyed-out
/// one. So this never shows an empty slot, a dashed outline or a "no image" glyph -- the three
/// standard ways an interface tells you that you have not finished. There is nothing to finish.
///
/// That is also why removing a photo is offered in the same breath as adding one. A control
/// that can only ever add is one that quietly makes the photo mandatory after the first tap.
struct PortraitWell: View {
    @Environment(\.accent) private var accent

    var portraitFile: String?
    var diameter: CGFloat = 96
    /// Draws the level gauge as a ring around the face when given. Outside the circle rather
    /// than over it -- a gauge drawn on top of a photograph is illegible against half the
    /// photographs anybody will ever choose.
    var progress: Double?
    /// Nil makes it a plain view. Everywhere it is editable, both actions are available.
    var onPick: (() -> Void)?
    var onClear: (() -> Void)?

    private var portrait: UIImage? { PhotoStore.loadPortrait(portraitFile) }

    /// How far the gauge sits outside the face.
    private static let gaugeGap: CGFloat = 14

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let progress {
                    // Track first, then the earned arc on top of it, so it reads as a gauge
                    // rather than as a decorative stroke.
                    Circle()
                        .stroke(Ink.groundSunk, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: max(0.02, progress))
                        .stroke(accent.signal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: diameter + Self.gaugeGap, height: diameter + Self.gaugeGap)
            .overlay { face }

            if onPick != nil {
                Menu {
                    Button(portrait == nil ? "Add a photo" : "Change photo", systemImage: "camera") {
                        onPick?()
                    }
                    if portrait != nil {
                        Button("Use my bear instead", systemImage: "arrow.uturn.backward", role: .destructive) {
                            onClear?()
                        }
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(accent.onSignal)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(accent.signal))
                        .overlay(Circle().strokeBorder(Ink.text, lineWidth: 3))
                }
                .accessibilityLabel(portrait == nil ? "Add a photo" : "Change or remove your photo")
                .offset(x: 2, y: 2)
            }
        }
    }

    private var face: some View {
        Group {
            if let portrait {
                Image(uiImage: portrait)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let bear = BearIcons.all[BearIcons.name(accent: accent.id, phase: nil)] {
                // Sat on its own colour, faintly, so the bear has a ground to be a cut-out
                // against rather than floating on the page.
                accent.signalLift.overlay {
                    Image(uiImage: bear)
                        .resizable()
                        .scaledToFit()
                        .padding(diameter * 0.08)
                }
            } else {
                accent.signal
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Ink.text, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)
    }
}
