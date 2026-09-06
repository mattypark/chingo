import Testing
import SwiftUI
import Foundation
@testable import ChinGoDesign

/// Astronomy is the kind of code that looks right and is an hour out, so these check against
/// facts that hold independently of the implementation: the geometry of solstices, the
/// definition of an equinox, and the polar day and night the whole altitude-based approach
/// exists to get right.
@Suite("Sky")
struct SkyTests {

    private func utc(_ y: Int, _ m: Int, _ d: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var parts = DateComponents()
        (parts.year, parts.month, parts.day, parts.hour, parts.minute) = (y, m, d, hour, minute)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: parts)!
    }

    /// Every altitude the sun reaches at this place across one day, sampled every 10 minutes.
    private func day(lat: Double, lon: Double, _ y: Int, _ m: Int, _ d: Int) -> [Double] {
        stride(from: 0, to: 24 * 60, by: 10).map {
            Sky.altitude(latitude: lat, longitude: lon, at: utc(y, m, d, $0 / 60, $0 % 60))
        }
    }

    // MARK: Solar position

    /// At the June solstice the sun stands at (90 - latitude + 23.44) degrees at local noon.
    /// San Francisco at 37.77 gives 75.7, and that is arithmetic rather than an observation,
    /// so it is a real check on the declination.
    @Test("Peak altitude at the June solstice matches the solstice geometry")
    func junePeakOverSanFrancisco() {
        let peak = day(lat: 37.7749, lon: -122.4194, 2026, 6, 21).max()!
        #expect(abs(peak - 75.67) < 0.5, "peak was \(peak), expected about 75.67")
    }

    /// Same identity in the other direction: 90 - latitude - 23.44 at the December solstice.
    @Test("Peak altitude at the December solstice matches too")
    func decemberPeakOverSanFrancisco() {
        let peak = day(lat: 37.7749, lon: -122.4194, 2026, 12, 21).max()!
        #expect(abs(peak - 28.79) < 0.5, "peak was \(peak), expected about 28.79")
    }

    /// On the equinox the sun passes directly overhead at the equator. If the equation of
    /// time or the hour angle is wrong this is the test that says so.
    @Test("The equinox sun stands overhead at the equator")
    func equinoxOverhead() {
        let peak = day(lat: 0, lon: 0, 2026, 3, 20).max()!
        #expect(peak > 89, "peak was \(peak), expected nearly 90")
    }

    /// The reason the whole thing is keyed on altitude rather than on sunrise and sunset:
    /// above the Arctic circle in June there is no sunrise to key on.
    @Test("Midnight sun: above the Arctic circle in June the sun never sets")
    func polarDay() {
        let lowest = day(lat: 69.6496, lon: 18.9560, 2026, 6, 21).min()!
        #expect(lowest > 0, "lowest was \(lowest), the sun should not have set")
    }

    @Test("Polar night: the same place in December never sees it rise")
    func polarNight() {
        let highest = day(lat: 69.6496, lon: 18.9560, 2026, 12, 21).max()!
        #expect(highest < 0, "highest was \(highest), the sun should not have risen")
    }

    /// Longitude has to enter through the hour angle. Two places on the same parallel, an
    /// hour of longitude apart, must peak an hour apart.
    @Test("Fifteen degrees of longitude moves noon by an hour")
    func longitudeShiftsNoon() {
        func peakMinute(lon: Double) -> Int {
            let samples = day(lat: 40, lon: lon, 2026, 5, 15)
            return samples.firstIndex(of: samples.max()!)! * 10
        }
        let apart = peakMinute(lon: 0) - peakMinute(lon: 15)
        #expect(abs(apart - 60) <= 10, "noon moved \(apart) minutes, expected about 60")
    }

    // MARK: Palette

    @Test("Altitudes past either end clamp instead of running off the stops")
    func bandClamps() {
        let highNoon = Sky.band(atAltitude: 89)
        let deepNight = Sky.band(atAltitude: -90)
        #expect(sameColour(highNoon.high, Sky.band(atAltitude: 60).high))
        #expect(sameColour(deepNight.high, Sky.band(atAltitude: -30).high))
    }

    /// From the top of golden hour down into night the sky only ever darkens. A palette that
    /// brightens somewhere on the way to midnight is a typo, and this is the stretch where
    /// six of the eleven stops live, so it is the stretch a typo would land in.
    ///
    /// Deliberately starts at +6 and not at noon. Above golden hour the *top* of the sky
    /// legitimately pales as the sun drops -- deepest blue is overhead at high sun -- so
    /// asserting monotonicity across full daylight would be asserting something false.
    @Test("The band darkens monotonically from golden hour into night")
    func twilightOnlyDarkens() {
        var previous = Double.infinity
        for altitude in stride(from: 6.0, through: -40.0, by: -0.5) {
            let level = luminance(Sky.band(atAltitude: altitude).high)
            #expect(level <= previous + 0.0005, "sky brightened at \(altitude) degrees")
            previous = level
        }
    }

    /// The coarse fact the whole feature rests on, checked at both ends of the band.
    @Test("Day is plainly brighter than night")
    func dayOutshinesNight() {
        for keyPath in [\(high: Color, low: Color).high, \(high: Color, low: Color).low] {
            #expect(luminance(Sky.band(atAltitude: 45)[keyPath: keyPath])
                    > luminance(Sky.band(atAltitude: -20)[keyPath: keyPath]) * 4)
        }
    }

    @Test("Night is called at astronomical dusk, not at sunset")
    func nightThreshold() {
        #expect(!Sky.isNight(atAltitude: 0))
        #expect(!Sky.isNight(atAltitude: -5))
        #expect(Sky.isNight(atAltitude: -7))
    }

    private func luminance(_ colour: Color) -> Double {
        let c = colour.resolve(in: EnvironmentValues())
        return 0.2126 * Double(c.linearRed) + 0.7152 * Double(c.linearGreen) + 0.0722 * Double(c.linearBlue)
    }

    private func sameColour(_ a: Color, _ b: Color) -> Bool {
        let (x, y) = (a.resolve(in: EnvironmentValues()), b.resolve(in: EnvironmentValues()))
        return abs(x.red - y.red) < 0.001 && abs(x.green - y.green) < 0.001 && abs(x.blue - y.blue) < 0.001
    }
}
