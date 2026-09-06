import SwiftUI
import ChinGoDesign

/// The basemap, corrected and tinted, before MapLibre ever sees it.
///
/// Two jobs, both of which have to happen to the *style* rather than to the loaded layers.
///
/// **Correcting the ground.** `scripts/build-style.py` keeps its own copy of the palette, and
/// the copy has drifted. It invented `land_alt` `#E9E2CF` -- a colour that appears nowhere in
/// `Ink` -- and paints it through a branch where the `landuse` case and the `else` case are
/// identical, so it lands on ten layers while the real `Ink.mapLand` reaches exactly one, the
/// background. At city zoom the ground you actually see is the invented darker colour, which
/// is why the map has always looked heavier than the palette says it should. Three building
/// colours have drifted too, and two upstream ones were never repainted at all.
///
/// `scripts/` belongs to the backend session, and the generated JSON carries a do-not-edit
/// banner because the next regeneration would silently discard the change. So the correction
/// is applied here, on the way in, from `Ink` -- the file DESIGN.md already names as the one
/// place map colour is allowed to come from.
///
/// **Tinting toward the accent.** A per-player colour cannot be baked into a static asset at
/// build time by definition. Only the neutral family is touched -- ground and buildings, the
/// largest surface in the product. Water and parks are left alone because they are semantic,
/// and jade water is the calm counterweight the accent is loud against; roads are left alone
/// because they carry the map's legibility and a wash across near-white is the most visible
/// place to spend it.
///
/// **Why the JSON and not the live layers.** Two of the colours that need correcting live
/// inside `interpolate` expressions -- the 3D building ramp keys off render height, the flat
/// building layer off zoom. Rewriting those through `MLNStyleLayer` means rebuilding
/// expressions; rewriting them here is a string substitution that cannot miss one.
enum MapStyle {

    /// Source colour in the generated style, and the `Ink` token it should have been.
    ///
    /// Keyed on the colour rather than on layer ids: ids come from upstream OpenMapTiles and
    /// can be renamed by a style regeneration, whereas this table is a statement about the
    /// palette, which is the thing that actually drifted.
    private static var corrections: [String: Color] {
        [
            "#EDE7D6": Ink.mapLand,           // background -- already right, still gets washed
            "#E9E2CF": Ink.mapLand,           // invented land_alt, on ten layers. The bug.
            "#F2EBDA": Ink.mapBuilding,       // drifted
            "#EADEC8": Ink.mapBuildingWarm,   // drifted
            "#DCCDB2": Ink.mapBuildingSide,   // drifted
            "#f2eae2": Ink.mapBuilding,       // upstream, never repainted (lowercase = untouched)
            "#dfdbd7": Ink.mapBuildingSide,   // upstream, never repainted
        ]
    }

    /// A style file painted for this accent, written once and reused.
    static func url(for accent: Accent) -> URL? {
        guard let source = Bundle.main.url(forResource: "chingo-style", withExtension: "json") else {
            return nil
        }

        let destination = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chingo-style-\(accent.id).json")

        if FileManager.default.fileExists(atPath: destination.path) { return destination }

        guard
            let data = try? Data(contentsOf: source),
            let root = try? JSONSerialization.jsonObject(with: data)
        else {
            // A style that will not parse is a map that will not draw, and the bundled one is
            // still perfectly usable -- it is only the wrong shade. Fall back rather than
            // trade a tint for a blank screen.
            return source
        }

        let table = swaps(for: accent)
        let painted = repaint(root, using: table)

        guard
            let out = try? JSONSerialization.data(withJSONObject: painted),
            (try? out.write(to: destination)) != nil
        else {
            return source
        }
        return destination
    }

    /// Every source colour mapped to its corrected, washed replacement.
    private static func swaps(for accent: Accent) -> [String: String] {
        corrections.reduce(into: [:]) { table, entry in
            table[entry.key.lowercased()] = hex(accent.washing(entry.value))
        }
    }

    /// The colour the ground actually ends up. `MapScreen` paints this behind the map so the
    /// frame or two before tiles arrive is the same shade as the frame after.
    static func ground(for accent: Accent) -> Color { accent.washing(Ink.mapLand) }

    /// Walks the whole document swapping colour strings wherever they appear, including
    /// inside the `interpolate` arrays that the building ramps are built from.
    private static func repaint(_ node: Any, using table: [String: String]) -> Any {
        switch node {
        case let text as String:
            return table[text.lowercased()] ?? text
        case let list as [Any]:
            return list.map { repaint($0, using: table) }
        case let object as [String: Any]:
            return object.mapValues { repaint($0, using: table) }
        default:
            return node
        }
    }

    // MARK: Colour

    private static func hex(_ colour: Color) -> String {
        let resolved = colour.resolve(in: EnvironmentValues())
        func channel(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X",
                      channel(resolved.red), channel(resolved.green), channel(resolved.blue))
    }
}
