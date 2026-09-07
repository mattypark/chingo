import SwiftUI

/// Where the sun actually is, and what colour that makes the sky.
///
/// **Why this is computed rather than fetched.** WeatherKit has sunrise and sunset and the
/// whole twilight set, and all of it is wrong for this: it needs a paid membership, it needs
/// the network, it puts a mandatory Apple Weather trademark on any screen that shows the
/// data, and it still only returns *event times* -- the interpolation between them would
/// still have to be written here. This is closed-form trigonometry. It runs offline, in
/// microseconds, for free.
///
/// **Why altitude and not the clock.** Keying a sky on "two hours after sunset" produces
/// nonsense above the Arctic circle, where there may be no sunset that day. Solar altitude is
/// defined everywhere, every day of the year, and polar day and polar night fall out of it
/// for free rather than needing to be special-cased.
///
/// The maths is NOAA's general solar position, itself out of Meeus. All of it runs in UTC and
/// converts only at the boundary, which is where essentially every bug in this subject lives.
public enum Sky {

    // MARK: Solar position

    /// Where the sun is: how high, and which way.
    ///
    /// `altitude` is degrees above the horizon, negative below it. `azimuth` is degrees
    /// clockwise from true north, so 90 is due east and 270 due west.
    public struct Position: Sendable, Equatable {
        public let altitude: Double
        public let azimuth: Double

        public init(altitude: Double, azimuth: Double) {
            self.altitude = altitude
            self.azimuth = azimuth
        }
    }

    /// The sun's altitude above the horizon, in degrees, at a coordinate and an instant.
    public static func altitude(latitude: Double, longitude: Double, at date: Date = .now) -> Double {
        position(latitude: latitude, longitude: longitude, at: date).altitude
    }

    /// Altitude and azimuth together, since both fall out of the same hour angle and
    /// declination and computing them separately would do the work twice.
    public static func position(latitude: Double, longitude: Double, at date: Date = .now) -> Position {
        let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let t = (julianDay - 2_451_545) / 36_525

        // Geometric mean longitude and anomaly of the sun.
        let meanLongitude = mod360(280.46646 + t * (36_000.76983 + t * 0.0003032))
        let meanAnomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        // Equation of centre: the difference between where a circular orbit would put the
        // sun and where the elliptical one does.
        let centre =
            sin(rad(meanAnomaly)) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(rad(2 * meanAnomaly)) * (0.019993 - 0.000101 * t)
            + sin(rad(3 * meanAnomaly)) * 0.000289

        let trueLongitude = meanLongitude + centre
        let apparentLongitude =
            trueLongitude - 0.00569 - 0.00478 * sin(rad(125.04 - 1_934.136 * t))

        let meanObliquity =
            23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = meanObliquity + 0.00256 * cos(rad(125.04 - 1_934.136 * t))

        let declination = asin(sin(rad(obliquity)) * sin(rad(apparentLongitude)))

        // Equation of time, in minutes: how far a sundial runs from a clock today.
        let y = pow(tan(rad(obliquity) / 2), 2)
        let equationOfTime = 4 * deg(
            y * sin(rad(2 * meanLongitude))
            - 2 * eccentricity * sin(rad(meanAnomaly))
            + 4 * eccentricity * y * sin(rad(meanAnomaly)) * cos(rad(2 * meanLongitude))
            - 0.5 * y * y * sin(rad(4 * meanLongitude))
            - 1.25 * eccentricity * eccentricity * sin(rad(2 * meanAnomaly))
        )

        // Minutes since midnight UTC, straight out of the Julian day's fractional part.
        let dayFraction = (julianDay + 0.5) - (julianDay + 0.5).rounded(.down)
        let minutesUTC = dayFraction * 1_440

        let trueSolarTime = minutesUTC + equationOfTime + 4 * longitude
        // Folded into -180...180. Far from Greenwich the raw value lands well outside it --
        // San Francisco at 01:00 UTC gives -289 degrees -- and while `cos` does not care,
        // the sign of this is what separates morning from afternoon further down. Left
        // unfolded, an evening sun in California reads as a morning one and comes up in the
        // east at six in the evening.
        let hourAngle = mod360(trueSolarTime / 4 - 180 + 180) - 180

        let cosZenith =
            sin(rad(latitude)) * sin(declination)
            + cos(rad(latitude)) * cos(declination) * cos(rad(hourAngle))
        let zenith = acos(min(max(cosZenith, -1), 1))

        // Azimuth from the same zenith. The denominator collapses at the poles and at exactly
        // zenith, so it is floored rather than allowed to divide by zero.
        let denominator = max(cos(rad(latitude)) * sin(zenith), 1e-9)
        let cosAzimuth = (sin(declination) - sin(rad(latitude)) * cosZenith) / denominator
        var azimuth = deg(acos(min(max(cosAzimuth, -1), 1)))
        // acos only ever returns 0...180, so mornings and afternoons come back identical.
        // The hour angle is what separates them: positive means the sun is past due south.
        if hourAngle > 0 { azimuth = 360 - azimuth }

        return Position(altitude: 90 - deg(zenith), azimuth: mod360(azimuth))
    }

    // MARK: Palette

    /// A keyframe: the sun at this altitude makes this sky.
    ///
    /// The stops are deliberately not evenly spaced. Everything interesting happens between
    /// +6 and -18 -- golden hour is -4 to +6, blue hour -6 to -4 -- so that 24-degree band
    /// carries six of the eleven stops and the whole of daylight gets two.
    private struct Stop {
        let altitude: Double
        let high: Color
        let low: Color
    }

    private static let stops: [Stop] = [
        Stop(altitude:  60, high: Color(hex: 0x8FBCE4), low: Color(hex: 0xCFE3F0)),
        Stop(altitude:  30, high: Color(hex: 0x93BEE3), low: Color(hex: 0xD8E7F0)),
        Stop(altitude:  10, high: Color(hex: 0xA6C3DE), low: Color(hex: 0xE6E7E2)),
        Stop(altitude:   6, high: Color(hex: 0xB4C1D6), low: Color(hex: 0xF0DEC0)),
        Stop(altitude:   2, high: Color(hex: 0xB09FC0), low: Color(hex: 0xF6C79A)),
        Stop(altitude:   0, high: Color(hex: 0x9A83B4), low: Color(hex: 0xF2A874)),
        Stop(altitude:  -4, high: Color(hex: 0x7A6AA6), low: Color(hex: 0xE0806E)),
        Stop(altitude:  -6, high: Color(hex: 0x53548C), low: Color(hex: 0xB05F72)),
        Stop(altitude: -12, high: Color(hex: 0x2E3566), low: Color(hex: 0x5B4A72)),
        Stop(altitude: -18, high: Color(hex: 0x1B2044), low: Color(hex: 0x2C2A4E)),
        Stop(altitude: -30, high: Color(hex: 0x141833), low: Color(hex: 0x1E1E38)),
    ]

    /// The two ends of the band at a given solar altitude, interpolated between keyframes.
    ///
    /// Mixed in `.perceptual` rather than sRGB. A naive channel-wise blend from amber to navy
    /// travels through mud, and the whole point of a continuous sky is the part in between.
    public static func band(atAltitude altitude: Double) -> (high: Color, low: Color) {
        guard let first = stops.first, let last = stops.last else { return (.clear, .clear) }
        if altitude >= first.altitude { return (first.high, first.low) }
        if altitude <= last.altitude { return (last.high, last.low) }

        for (upper, lower) in zip(stops, stops.dropFirst()) where altitude <= upper.altitude && altitude >= lower.altitude {
            let span = upper.altitude - lower.altitude
            let fraction = span == 0 ? 0 : (upper.altitude - altitude) / span
            return (
                upper.high.mix(with: lower.high, by: fraction),
                upper.low.mix(with: lower.low, by: fraction)
            )
        }
        return (last.high, last.low)
    }

    /// True once the sun is far enough down that the sky is properly dark. Chrome that needs
    /// to know whether it is night should ask this rather than reading a clock.
    public static func isNight(atAltitude altitude: Double) -> Bool { altitude < -6 }

    // MARK: Maths

    private static func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func deg(_ radians: Double) -> Double { radians * 180 / .pi }
    private static func mod360(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
