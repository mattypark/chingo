import Testing
@testable import ChinGoEngine

@Suite("Geo")
struct GeoCellTests {

    @Test("Nearby points share a cell")
    func nearbyPointsShareACell() {
        // Two points about 40 m apart in San Francisco.
        let a = GeoCell(latitude: 37.75950, longitude: -122.42710)
        let b = GeoCell(latitude: 37.75962, longitude: -122.42718)
        #expect(a == b)
    }

    @Test("Distant points do not share a cell")
    func distantPointsDiffer() {
        let sf = GeoCell(latitude: 37.7595, longitude: -122.4271)
        let seoul = GeoCell(latitude: 37.5665, longitude: 126.9780)
        #expect(sf != seoul)
    }

    @Test("A cell id throws away precision")
    func cellIsCoarse() {
        // Fifty distinct coordinates spread over roughly a 100 m box collapse into a
        // handful of ids. That collapse is the privacy guarantee: by the time a position
        // is written down there is no precise location left in it.
        //
        // "A handful" and not "one" because this is a square grid, so a box straddling a
        // grid line lands in up to four cells. Two people on opposite kerbs of the same
        // street can therefore fall in different cells — the known weakness of equal-angle
        // quantisation, and the reason H3's equidistant hex neighbours are the eventual
        // answer. It is a discovery miss, never a privacy leak.
        var ids = Set<String>()
        for i in 0..<50 {
            let lat = 37.7590 + Double(i) * 0.00002
            let lon = -122.4270 + Double(i % 7) * 0.00002
            ids.insert(GeoCell(latitude: lat, longitude: lon).id)
        }
        #expect(ids.count <= 4)
        #expect(ids.count < 50)
    }

    @Test("The antimeridian does not split a place in two")
    func antimeridianFolds() {
        #expect(GeoCell(latitude: 0, longitude: 180) == GeoCell(latitude: 0, longitude: -180))
    }

    @Test("Haversine matches known distances")
    func haversine() {
        // SF to Seoul is about 9,050 km.
        let d = Geo.metres(from: (37.7749, -122.4194), to: (37.5665, 126.9780))
        #expect(d > 9_000_000 && d < 9_100_000)

        // A short walk.
        let short = Geo.metres(from: (37.7749, -122.4194), to: (37.7758, -122.4194))
        #expect(short > 95 && short < 105)
    }
}
