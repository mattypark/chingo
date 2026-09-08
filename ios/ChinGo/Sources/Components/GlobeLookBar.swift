import SwiftUI
import MapKit
import ChinGoDesign

/// The three ways the globe can look.
///
/// Deliberately three and not six. Apple Maps offers Terrain, Traffic, Transit and Biking as
/// well, and every one of them answers a question about getting somewhere -- which is not the
/// question this screen exists for. What changes here is only how the Earth is drawn.
enum GlobeLook: String, CaseIterable, Identifiable {
    /// Our own style on MapLibre. Near-white paper, white roads, pale water.
    case map
    /// MapKit, far enough out to be a lit sphere on a starfield.
    case globe

    /// Satellite used to be here and came off. It was somebody else's aesthetic dropped into
    /// the middle of an app made of flat colour and hard outlines, and at the zoom this screen
    /// is actually used at -- somebody's own city -- a photograph is harder to read than a
    /// drawing. What is left is a real choice: the city, or the planet.
    static let fallback: GlobeLook = .map

    var id: String { rawValue }

    var title: String {
        switch self {
        case .map: "Map"
        case .globe: "Globe"
        }
    }

    var icon: String {
        switch self {
        case .map: "map.fill"
        case .globe: "globe.americas.fill"
        }
    }

    /// Which renderer draws it. They are genuinely different engines, not two settings on one:
    /// MapKit is the only one that can draw a sphere, and MapLibre is the only one whose
    /// colours we control.
    var isSphere: Bool { self == .globe }

    /// MapKit's configuration, for the sphere. Realistic elevation is what makes it curve --
    /// and is also why the friends on this screen are drawn as a SwiftUI overlay rather than
    /// as annotations: under realistic elevation MapKit never asks for an annotation view at
    /// all, with nothing logged.
    @MainActor
    var configuration: MKMapConfiguration {
        MKHybridMapConfiguration(elevationStyle: .realistic)
    }
}

/// Apple Maps' layer row, in this app's language.
///
/// Tiles rather than a menu, because the choice is visual: the labels are almost useless on
/// their own -- "Satellite" and "Globe" are both photographs of the Earth -- and what actually
/// tells them apart is seeing them. The selected one takes the accent and sinks into its own
/// shadow, the same press state every other sticker in the app uses.
struct GlobeLookBar: View {
    @Environment(\.accent) private var accent
    @Binding var selection: GlobeLook

    var body: some View {
        HStack(spacing: Space.tight) {
            ForEach(GlobeLook.allCases) { look in
                let chosen = look == selection

                Button { selection = look } label: {
                    VStack(spacing: Space.hair) {
                        Image(systemName: look.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(chosen ? accent.onSignal : Ink.text)
                        Text(look.title)
                            .font(.custom(Typeface.bagel, size: 11))
                            .foregroundStyle(chosen ? accent.onSignal : Ink.textSoft)
                    }
                    .frame(width: 74, height: 58)
                }
                .buttonStyle(
                    StickerButtonStyle(
                        fill: chosen ? accent.signal : Ink.groundRaised,
                        radius: Radius.control
                    )
                )
                .accessibilityLabel(look.title)
                .accessibilityAddTraits(chosen ? [.isSelected] : [])
            }
        }
    }
}
