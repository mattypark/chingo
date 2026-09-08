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
    /// palette.
    ///
    /// It started as a list of colours that had *drifted* from `Ink`. It is now the whole map
    /// palette, because the generated style is still the warm paper one and every colour in it
    /// has to be replaced on the way in. When `build-style.py` catches up this shrinks back to
    /// the drift list -- see docs/HANDOFF-MAP-PALETTE.md.
    private static var corrections: [String: Color] {
        [
            "#EDE7D6": Ink.mapLand,           // background
            "#E9E2CF": Ink.mapLand,           // invented land_alt, on ten layers. The bug.
            "#CFE0BC": Ink.mapPark,           // parks and grass
            "#A8D8D0": Ink.mapWater,          // water
            "#FFFDF7": Ink.mapRoad,           // the carriageway, on 38 layers
            "#DDD5C2": Ink.mapRoadCasing,     // its edge, on 23
            "#F2EBDA": Ink.mapBuilding,       // drifted; layer is stripped, kept for the map
            "#EADEC8": Ink.mapBuildingWarm,   // drifted
            "#DCCDB2": Ink.mapBuildingSide,   // drifted
            "#f2eae2": Ink.mapBuilding,       // upstream, never repainted (lowercase = untouched)
            "#dfdbd7": Ink.mapBuildingSide,   // upstream, never repainted
        ]
    }

    /// Bump on every change to any transform below.
    ///
    /// The painted style is cached per accent, and `url(for:)` returns the cached file without
    /// looking inside it. So a transform change that keeps the same version is invisible --
    /// the app serves the old style forever and it reads as the code having done nothing.
    /// That has already cost one debugging session in this file. It is a named constant
    /// rather than a literal buried in a filename so that changing a transform and forgetting
    /// this are at least next to each other.
    private static let styleVersion = 5

    /// A style file painted for this accent, written once and reused.
    static func url(for accent: Accent) -> URL? {
        guard let source = Bundle.main.url(forResource: "chingo-style", withExtension: "json") else {
            return nil
        }

        let destination = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chingo-style-\(accent.id)-v\(styleVersion).json")

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
        let painted = removeBuildings(widenStreets(repaint(root, using: table)))

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

    // MARK: Buildings

    /// Buildings are removed from the style entirely.
    ///
    /// The clamp this replaces was the wrong answer to the right problem. Short buildings
    /// still pop in and out as you cross the zoom where the clamp engages, and they still
    /// hide the ground you are standing on. Pokemon GO's answer is simpler and better: there
    /// are no buildings. Stand inside one and the map shows the street, because the street is
    /// the thing you are playing on.
    ///
    /// Dropping the layer rather than hiding it also removes the last thing that made zoom
    /// feel unstable -- there is nothing left whose geometry changes as you pinch.
    private static let buildingLayers = ["chingo-building-3d", "building", "building-top"]

    private static func removeBuildings(_ root: Any) -> Any {
        guard var document = root as? [String: Any],
              let layers = document["layers"] as? [[String: Any]] else { return root }

        document["layers"] = layers.filter { layer in
            guard let id = layer["id"] as? String else { return true }
            return !buildingLayers.contains(id)
        }
        return document
    }

    /// How much wider the roads get.
    ///
    /// The basemap comes from a navigation style, where a road is a line telling you a route
    /// exists. Here the street is the floor you are standing on -- the camera is raked along
    /// it and it should read as ground with width, not as a drawn route. Everything else in
    /// the style stays as it is; only the carriageway and its casing grow.
    private static let streetScale: Double = 1.75

    /// Layers whose lines are not streets and must not grow with them.
    private static let notStreets = ["waterway", "boundary", "admin", "aeroway", "ferry", "rail"]

    /// Scales `line-width` and `line-gap-width` on the road layers.
    ///
    /// The widths are `interpolate` expressions -- `[op, curve, input, zoom, width, zoom,
    /// width, ...]` -- so only the output half of each stop is scaled. Multiplying the zoom
    /// stops as well would move where the roads change width rather than how wide they are,
    /// which looks like the map zooming on its own.
    private static func widenStreets(_ root: Any) -> Any {
        guard var document = root as? [String: Any],
              let layers = document["layers"] as? [[String: Any]] else { return root }

        document["layers"] = layers.map { layer -> [String: Any] in
            guard layer["type"] as? String == "line",
                  let id = layer["id"] as? String,
                  !notStreets.contains(where: { id.contains($0) }),
                  var paint = layer["paint"] as? [String: Any]
            else { return layer }

            var widened = layer
            for key in ["line-width", "line-gap-width"] {
                guard let value = paint[key] else { continue }
                paint[key] = scaleOutputs(value)
            }
            widened["paint"] = paint
            return widened
        }
        return document
    }

    /// Multiplies the widths an expression produces, leaving the zooms it keys off alone.
    private static func scaleOutputs(_ value: Any) -> Any {
        if let number = value as? Double { return number * streetScale }
        if let number = value as? Int { return Double(number) * streetScale }
        guard var parts = value as? [Any], parts.count > 3,
              parts.first as? String == "interpolate" else { return value }

        // index 0 op, 1 curve, 2 input, then alternating stop-in / stop-out.
        var index = 4
        while index < parts.count {
            if let number = parts[index] as? Double { parts[index] = number * streetScale }
            else if let number = parts[index] as? Int { parts[index] = Double(number) * streetScale }
            index += 2
        }
        return parts
    }

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
