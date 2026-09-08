import SwiftUI
import MapKit
import ChinGoDesign

/// The three ways the globe can look.
///
/// Deliberately three and not six. Apple Maps offers Terrain, Traffic, Transit and Biking as
/// well, and every one of them answers a question about getting somewhere -- which is not the
/// question this screen exists for. What changes here is only how the Earth is drawn.
enum GlobeLook: String, CaseIterable, Identifiable {
    /// Flat, drawn, labelled. Closest to the rest of the app.
    case map
    /// Photographic, flat.
    case satellite
    /// Photographic, and an actual sphere on a starfield.
    case globe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .map: "Map"
        case .satellite: "Satellite"
        case .globe: "Globe"
        }
    }

    var icon: String {
        switch self {
        case .map: "map.fill"
        case .satellite: "photo.fill"
        case .globe: "globe.americas.fill"
        }
    }

    /// **Only `.globe` uses realistic elevation, and only it is a sphere.** Flat elevation
    /// renders the same imagery as an ordinary map however far out the camera goes -- no
    /// curve, no starfield, no terminator. It is also the one that lets `MKAnnotationView`
    /// work, which is why the friends on this screen are drawn as a SwiftUI overlay instead:
    /// under realistic elevation MapKit never asks for an annotation view at all, so anything
    /// relying on annotations would silently empty itself when somebody picked Globe.
    @MainActor
    var configuration: MKMapConfiguration {
        switch self {
        case .map: MKStandardMapConfiguration(elevationStyle: .flat)
        case .satellite: MKImageryMapConfiguration(elevationStyle: .flat)
        case .globe: MKHybridMapConfiguration(elevationStyle: .realistic)
        }
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
