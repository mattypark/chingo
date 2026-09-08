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
    /// Which map this is being painted for.
    ///
    /// The two are not the same product surface and should not share numbers. The street map
    /// is a board you play on at walking scale, so it shouts: saturated green, dark ribbons,
    /// yellow edges, roads two and a half times their cartographic width. Pull back to a whole
    /// city on the globe screen and every one of those choices becomes noise -- there is
    /// nothing to play on at that zoom, only somebody to find.
    enum Kind: String {
        /// The game board. Green, loud, roads you could walk down.
        case street
        /// The backdrop on the globe screen. Near-white, quiet, everything saturated on it is
        /// a person.
        case flat
    }

    private static func corrections(for kind: Kind) -> [String: Color] {
        switch kind {
        case .street: streetCorrections
        case .flat: flatCorrections
        }
    }

    /// Near-white paper, white roads, pale water. Roads come out as negative space rather than
    /// as drawn lines, which is why this kind of map stays calm even over a dense city.
    private static var flatCorrections: [String: Color] {
        [
            "#EDE7D6": Ink.flatLand,
            "#E9E2CF": Ink.flatParcel,
            "#CFE0BC": Ink.flatPark,
            "#A8D8D0": Ink.flatWater,
            "#FFFDF7": Ink.flatRoad,
            "#DDD5C2": Ink.flatRoadCasing,
            "#F2EBDA": Ink.flatParcel,
            "#EADEC8": Ink.flatParcel,
            "#DCCDB2": Ink.flatParcel,
            "#f2eae2": Ink.flatParcel,
            "#dfdbd7": Ink.flatParcel,
        ]
    }

    private static var streetCorrections: [String: Color] {
        [
            "#EDE7D6": Ink.mapLand,           // background
            // Was the generator's invented `land_alt`, and a bug when it was a darker warm
            // grey standing in for the ground. Now it is doing a real job: it lands on the
            // landuse parcels, and a green a few points off the ground is exactly the texture
            // the map needs with the buildings gone.
            "#E9E2CF": Ink.mapLandParcel,
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
    private static let styleVersion = 9

    /// A style file painted for this accent, written once and reused.
    static func url(for accent: Accent, kind: Kind = .street) -> URL? {
        guard let source = Bundle.main.url(forResource: "chingo-style", withExtension: "json") else {
            return nil
        }

        let destination = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chingo-style-\(kind.rawValue)-\(accent.id)-v\(styleVersion).json")

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

        let table = swaps(for: accent, kind: kind)
        let painted = deepenParks(
            solidPaths(
                roundStreets(
                    ribbonCasings(
                        removeBuildings(widenStreets(repaint(root, using: table), kind: kind)),
                        kind: kind
                    )
                ),
                for: accent,
                kind: kind
            ),
            for: accent,
            kind: kind
        )

        guard
            let out = try? JSONSerialization.data(withJSONObject: painted),
            (try? out.write(to: destination)) != nil
        else {
            return source
        }
        return destination
    }

    /// Every source colour mapped to its corrected, washed replacement.
    private static func swaps(for accent: Accent, kind: Kind) -> [String: String] {
        corrections(for: kind).reduce(into: [:]) { table, entry in
            table[entry.key.lowercased()] = hex(accent.washing(entry.value))
        }
    }

    /// The colour the ground actually ends up. `MapScreen` paints this behind the map so the
    /// frame or two before tiles arrive is the same shade as the frame after.
    static func ground(for accent: Accent, kind: Kind = .street) -> Color {
        accent.washing(kind == .street ? Ink.mapLand : Ink.flatLand)
    }

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
    ///
    /// The number comes from measuring the reference rather than from taste: in Pokemon GO a
    /// primary street is about 8% of the screen's width, where this basemap gives it 3%. With
    /// the buildings gone the road network is the only structure left on the ground, so it has
    /// to carry the whole map on its own, and at navigation widths it cannot.
    private static func streetScale(for kind: Kind) -> Double {
        switch kind {
        case .street: 2.6
        // Barely widened. On the flat map a road is a thing you look past, and the reference
        // this is modelled on draws them at ordinary cartographic width.
        case .flat: 1.15
        }
    }

    /// How wide the ribbon is, counting its edges, as a multiple of the carriageway.
    ///
    /// Measured off a Pokemon GO screenshot: a 98px carriageway carries a 17-20px casing on
    /// each side, so the outer edge is about 1.38x the fill -- roughly a fifth of the road's
    /// width in yellow on each side. That is far heavier than any navigation style, where a
    /// casing is a hairline separating two roads rather than the edge of a physical object,
    /// and it is most of the difference between a map and a game board.
    private static func casingRatio(for kind: Kind) -> Double {
        switch kind {
        case .street: 1.38
        // A hairline, not a ribbon. The yellow edge is a game decision; here the casing only
        // has to stop two white roads merging into one white shape.
        case .flat: 1.14
        }
    }

    /// Footpaths do not grow with the roads.
    ///
    /// They are already drawn thin and they are drawn *everywhere* -- San Francisco has its
    /// pavements mapped, so every street comes with two of them. Scaled up with the roads they
    /// stop reading as pavements and start reading as a second, paler street network running
    /// parallel to the first.
    private static let pathScale: Double = 0.9


    /// Layers whose lines are not streets and must not grow with them.
    private static let notStreets = ["waterway", "boundary", "admin", "aeroway", "ferry", "rail"]

    /// Scales `line-width` and `line-gap-width` on the road layers.
    ///
    /// The widths are `interpolate` expressions -- `[op, curve, input, zoom, width, zoom,
    /// width, ...]` -- so only the output half of each stop is scaled. Multiplying the zoom
    /// stops as well would move where the roads change width rather than how wide they are,
    /// which looks like the map zooming on its own.
    private static func widenStreets(_ root: Any, kind: Kind) -> Any {
        guard var document = root as? [String: Any],
              let layers = document["layers"] as? [[String: Any]] else { return root }

        document["layers"] = layers.map { layer -> [String: Any] in
            guard layer["type"] as? String == "line",
                  let id = layer["id"] as? String,
                  !notStreets.contains(where: { id.contains($0) }),
                  var paint = layer["paint"] as? [String: Any]
            else { return layer }

            // Casings are not scaled here at all -- `ribbonCasings` overwrites them from the
            // road they wrap, which is the only way to get one ratio at every zoom and for
            // every class out of a style whose casing widths were each tuned by hand.
            let scale = id.hasSuffix("-path") ? pathScale : streetScale(for: kind)
            var widened = layer
            for key in ["line-width", "line-gap-width"] {
                guard let value = paint[key] else { continue }
                paint[key] = scaleOutputs(value, by: scale)
            }
            widened["paint"] = paint
            return widened
        }
        return document
    }

    /// Rebuilds every casing width from the road it wraps.
    ///
    /// The generated style gives each class its own hand-tuned casing -- 15 against a 11.5 road
    /// here, 22 against 18 there -- so the fraction of the ribbon that is yellow changes from
    /// street to street and from zoom to zoom. That is correct for a navigation map, where the
    /// casing's job is to separate two roads that touch, and wrong here, where it is the edge
    /// of a physical thing and the thing does not change proportions when you look at more of
    /// it.
    ///
    /// So the casing stops being an independent number: it is the road's own width expression,
    /// multiplied. Run after `widenStreets`, so it inherits the widened road for free.
    private static func ribbonCasings(_ root: Any, kind: Kind) -> Any {
        guard var document = root as? [String: Any],
              let layers = document["layers"] as? [[String: Any]] else { return root }

        var roadWidths: [String: Any] = [:]
        for layer in layers {
            guard let id = layer["id"] as? String, !id.hasSuffix("-casing"),
                  let width = (layer["paint"] as? [String: Any])?["line-width"] else { continue }
            roadWidths[id] = width
        }

        document["layers"] = layers.map { layer -> [String: Any] in
            guard let id = layer["id"] as? String, id.hasSuffix("-casing"),
                  let road = roadWidths[String(id.dropLast("-casing".count))],
                  var paint = layer["paint"] as? [String: Any]
            else { return layer }

            paint["line-width"] = scaleOutputs(road, by: casingRatio(for: kind))
            var ribbon = layer
            ribbon["paint"] = paint
            return ribbon
        }
        return document
    }

    /// Round caps and joins on everything that is a street.
    ///
    /// The generated style sets them on some classes and not others, which is invisible at
    /// navigation widths and impossible to miss at these -- a butt cap on a 30pt road leaves a
    /// square end hanging in the grass wherever a way is split, and a mitre join spikes at
    /// every corner. Round on both gives the capsule ends and the smooth corners the reference
    /// has, and costs nothing.
    ///
    /// It has to be a constant. `line-cap` accepts an expression in the spec and silently does
    /// not on MapLibre Native iOS, so a `["step", ["zoom"], ...]` here would look correct in
    /// the JSON and do nothing on the phone.
    private static func roundStreets(_ root: Any) -> Any {
        guard var document = root as? [String: Any],
              let layers = document["layers"] as? [[String: Any]] else { return root }

        document["layers"] = layers.map { layer -> [String: Any] in
            guard layer["type"] as? String == "line",
                  let id = layer["id"] as? String,
                  !notStreets.contains(where: { id.contains($0) })
            else { return layer }

            var rounded = layer
            var layout = layer["layout"] as? [String: Any] ?? [:]
            layout["line-cap"] = "round"
            layout["line-join"] = "round"
            rounded["layout"] = layout
            return rounded
        }
        return document
    }

    /// Multiplies the widths an expression produces, leaving the zooms it keys off alone.
    private static func scaleOutputs(_ value: Any, by streetScale: Double) -> Any {
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

    // MARK: Paths

    /// Footpaths, drawn as pale solid ribbons instead of dashed roads.
    ///
    /// Three things happen here, and none of them can be done by the colour table because
    /// paths share the carriageway's colour in the generated style and are only distinguished
    /// by layer id.
    ///
    /// 1. **The dashes go.** `line-dasharray: [1.5, 0.75]` is why downtown looks stitched --
    ///    San Francisco has its footways mapped, so every street gets a dashed line running
    ///    beside it. A dash says "this is a route, and it is provisional"; the ground you are
    ///    walking on is neither.
    /// 2. **They get their own colour.** Near-white with a cyan cast, so a path reads as a
    ///    different kind of surface rather than as a thin road.
    /// 3. **The casing goes.** Paths are the one part of the network with no yellow edge,
    ///    which is what stops a pavement reading as a street.
    private static func solidPaths(_ root: Any, for accent: Accent, kind: Kind) -> Any {
        guard var document = root as? [String: Any],
              let layers = document["layers"] as? [[String: Any]] else { return root }

        let colour = hex(accent.washing(kind == .street ? Ink.mapPath : Ink.flatPath))

        document["layers"] = layers.compactMap { layer -> [String: Any]? in
            guard let id = layer["id"] as? String, id.hasSuffix("-path") || id.hasSuffix("-path-casing")
            else { return layer }
            guard !id.hasSuffix("-casing") else { return nil }

            var solid = layer
            var paint = layer["paint"] as? [String: Any] ?? [:]
            paint["line-dasharray"] = nil
            paint["line-color"] = colour
            solid["paint"] = paint
            return solid
        }
        return document
    }

    /// Protected land, one step darker than an ordinary park.
    ///
    /// The generated style paints a national park and a neighbourhood lawn the same colour,
    /// which is fine on a navigation map where both are "green space" and neither is somewhere
    /// you go. Here the ground is already green, so the whole park family has to climb away
    /// from it, and a reserve that stops where a lawn stops has nothing left to say.
    private static func deepenParks(_ root: Any, for accent: Accent, kind: Kind) -> Any {
        guard var document = root as? [String: Any],
              let layers = document["layers"] as? [[String: Any]] else { return root }

        let colour = hex(accent.washing(kind == .street ? Ink.mapParkDeep : Ink.flatParkDeep))

        document["layers"] = layers.map { layer -> [String: Any] in
            guard layer["id"] as? String == "park", var paint = layer["paint"] as? [String: Any]
            else { return layer }
            paint["fill-color"] = colour
            var deepened = layer
            deepened["paint"] = paint
            return deepened
        }
        return document
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
