import Foundation

/// Coarsening a position into a cell, before it is stored or sent anywhere.
///
/// This is the function that makes the privacy model true rather than aspirational: a
/// coordinate is quantised here, at the edge, so a precise position never reaches the
/// database in the first place. There is nothing to leak later because it was never
/// written down.
///
/// The scheme is a plain equal-angle quantisation, not H3. H3 is the right long-term answer
/// — its hex neighbours are equidistant, which matters for "who is in an adjacent cell" —
/// but it is a third-party dependency, and this needs to exist and be tested first. The
/// swap is contained entirely inside this file.
public struct GeoCell: Hashable, Sendable, CustomStringConvertible {
    public let id: String

    public var description: String { id }

    /// ~150 m at the equator, which is the radius a memory should surface at. Small enough
    /// that "you are here" is true, large enough that a cell is a block rather than a
    /// doorstep.
    public static let degreesPerCell = 0.00135

    public init(latitude: Double, longitude: Double, precision: Double = GeoCell.degreesPerCell) {
        // Longitude is folded so ±180 does not produce two cells for one place.
        let lon = ((longitude + 180).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) - 180
        let lat = min(max(latitude, -90), 90)

        let latIndex = Int((lat / precision).rounded(.down))
        let lonIndex = Int((lon / precision).rounded(.down))
        id = "c\(latIndex)_\(lonIndex)"
    }

    public init(id: String) { self.id = id }
}

public enum Geo {
    /// Metres between two coordinates. Haversine — good to well under a metre at the
    /// distances this app cares about, and it needs no dependency.
    public static func metres(
        from a: (lat: Double, lon: Double),
        to b: (lat: Double, lon: Double)
    ) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180

        let h = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        return 2 * earthRadius * asin(min(1, h.squareRoot()))
    }

    /// How close you must get before a memory surfaces.
    ///
    /// 150 m rather than 30 m: the point is to catch you as you pass the end of the street,
    /// while there is still time to turn around, not to require you to stand on the exact
    /// paving stone.
    public static let memoryRadiusMetres: Double = 150
}
