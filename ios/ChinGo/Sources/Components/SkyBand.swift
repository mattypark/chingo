import SwiftUI
import ChinGoDesign

/// The sky, tracking the real sun where the player actually is.
///
/// Three layers, all driven off one number -- the sun's altitude:
///
/// 1. **The band.** A gradient down the top of the screen, thinning to nothing.
/// 2. **The sun.** A disc placed by real solar azimuth, so turning the phone turns toward it.
/// 3. **The light.** A wash over the whole map that warms at golden hour and cools at night,
///    because a sunset sky over a noon-bright street is two times of day on one screen.
///
/// **What the band honestly is.** The camera is raked all the way back now, so a horizon does
/// come into view -- but the tiles run out behind it, and this is what covers that. Sky at the
/// top, thinning into the far edge of the map, which is the read Pokemon GO gets from its own.
///
/// **On the soft edges.** Everything printed *on* the world -- pills, cards, the bar, the puck
/// -- is hard-edged and zero-blur, and stays that way. This is not printed on the world; it is
/// the world. A sky with a hard bottom edge is a coloured rectangle stuck to the screen, and a
/// sun with a hard edge is a sticker of a sun.
struct SkyBand: View {
    var latitude: Double
    var longitude: Double
    /// Where the camera is facing, so the sun can be placed relative to it.
    var bearing: Double

    @State private var sun: Sky.Position

    /// How much of the screen the haze reaches down.
    private static let reach: CGFloat = 0.36
    /// Where the horizon sits, as a fraction of screen height, at the raked-back pitch the
    /// map opens at. Measured off the render rather than derived -- the projection depends on
    /// pitch, zoom and field of view together, and a number read off the thing it has to
    /// match is more honest than three approximations multiplied.
    private static let horizon: CGFloat = 0.30

    init(latitude: Double, longitude: Double, bearing: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.bearing = bearing
        _sun = State(initialValue: SkyBand.currentPosition(latitude, longitude))
    }

    var body: some View {
        let band = Sky.band(atAltitude: sun.altitude)

        GeometryReader { geo in
            ZStack(alignment: .top) {
                LinearGradient(colors: [band.high, band.low], startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.size.height * Self.reach)
                    .mask { horizonMask }

                Clouds(bearing: bearing, tint: band.high)
                    .frame(height: geo.size.height * Self.reach)
                    // The same horizon the gradient uses. Without it the low deck drifts on
                    // past the skyline and ends up as pale blobs lying across the street,
                    // which reads as a rendering fault rather than as weather.
                    .mask { horizonMask }
                    // Behind the sun, so the sun burns through them rather than sitting on
                    // top like a sticker.
                    .opacity(cloudOpacity)

                if let place = sunPlacement(in: geo.size) {
                    sunDisc.position(place)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .overlay { light }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(Motion.reduceMotion ? nil : .easeInOut(duration: 1.2), value: sun)
        .task(id: "\(latitude),\(longitude)") {
            // The sun moves a quarter of a degree a minute, against a palette whose narrowest
            // keyframe band is two degrees wide. A minute between samples is invisible.
            while !Task.isCancelled {
                sun = Self.currentPosition(latitude, longitude)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    /// Where the sky stops and the ground begins.
    ///
    /// Solid most of the way down and then off quickly. A long even fade dissolves the far
    /// buildings into the sky and the horizon stops being anywhere; holding it opaque to two
    /// thirds keeps a line there for the ground to end at.
    ///
    /// Shared by the gradient and the clouds, because two different horizons on one screen is
    /// two skies.
    private var horizonMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.62),
                .init(color: .black.opacity(0.55), location: 0.82),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: The sun

    /// A soft disc with a halo, sized so it reads as the sun rather than as a light.
    private var sunDisc: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Self.glare.opacity(0.78), Self.glare.opacity(0)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 104
                    )
                )
                .frame(width: 208, height: 208)

            Circle()
                .fill(Self.glare)
                .frame(width: 54, height: 54)
                .blur(radius: 7)
        }
        // Fades out as it climbs. A disc pinned in a midday sky is a decal; near the horizon,
        // which is the only place the camera can see anyway, it is the sun.
        .opacity(discOpacity)
    }

    /// Warm white. Not the accent: the sun is the one thing on screen that belongs to the
    /// world rather than to the player, and tinting it their colour would say otherwise.
    private static let glare = Color(hex: 0xFFF0C8)

    private var discOpacity: Double {
        // Full through golden hour, gone by the time it is properly up or properly down.
        switch sun.altitude {
        case ..<(-7): 0
        case -7 ..< 0: (sun.altitude + 7) / 7
        case 0 ... 18: 1
        case 18 ..< 34: (34 - sun.altitude) / 16
        default: 0
        }
    }

    /// Where the sun lands on screen, or nil when it is behind you.
    ///
    /// **The direction is real; the arc is not.** The map's actual horizontal field of view is
    /// under twenty degrees, so a physically-placed sun would be off screen almost always and
    /// the feature would amount to a disc nobody ever sees. Spreading a 150-degree arc across
    /// the width keeps it findable and keeps turning the phone meaningful -- the sun sits
    /// where the sun is, it just travels less far than it would in life.
    private func sunPlacement(in size: CGSize) -> CGPoint? {
        let offset = ((sun.azimuth - bearing).truncatingRemainder(dividingBy: 360) + 540)
            .truncatingRemainder(dividingBy: 360) - 180
        guard abs(offset) <= 75 else { return nil }

        let x = size.width * (0.5 + offset / 150)
        // Altitude lifts it off the horizon. Compressed for the same reason as the arc.
        let y = size.height * (Self.horizon - CGFloat(sun.altitude) * 0.007)
        return CGPoint(x: x, y: y)
    }

    // MARK: The light on everything else

    /// A wash over the whole map, in two passes that do different jobs.
    ///
    /// **Tint** is soft light, which shifts hue without flattening the map -- roads stay
    /// legible, labels stay readable, and the ground picks up whatever the sky is doing.
    ///
    /// **Dusk** is a plain dark layer, because soft light alone cannot make anything dark. A
    /// deep navy sky over a street lit like noon is two times of day on one screen, and soft
    /// light was politely tinting the street mauve while leaving it just as bright.
    private var light: some View {
        let band = Sky.band(atAltitude: sun.altitude)
        return ZStack {
            band.low
                .opacity(tintOpacity)
                .blendMode(.softLight)

            band.high
                .opacity(duskOpacity)
        }
        .allowsHitTesting(false)
    }

    /// Clouds fade out after dark rather than sitting there as white shapes on a night sky.
    /// They are still there at dusk, catching the last of the colour, which is the best they
    /// ever look.
    private var cloudOpacity: Double {
        switch sun.altitude {
        case 4...: 1
        case -6 ..< 4: (sun.altitude + 6) / 10
        default: 0
        }
    }

    /// Nothing at midday, most through golden hour, easing off once the colour has gone.
    private var tintOpacity: Double {
        switch sun.altitude {
        case 30...: 0
        case 6 ..< 30: (30 - sun.altitude) / 24 * 0.18
        case -8 ..< 6: 0.18 + (6 - sun.altitude) / 14 * 0.20
        default: 0.22
        }
    }

    /// Starts at the horizon and deepens to full night.
    ///
    /// Deliberately stops well short of dark. The basemap is a daylight style -- its street
    /// names and shop labels are dark grey chosen against cream -- so every point of darkening
    /// here is legibility spent. A genuinely dark night needs a second style with its own
    /// label colours, which is `build-style.py`'s to give and is written up in
    /// docs/HANDOFF-MAP-PALETTE.md. Until then this reads as evening, and evening is readable.
    private var duskOpacity: Double {
        switch sun.altitude {
        case 0...: 0
        case -18 ..< 0: -sun.altitude / 18 * 0.34
        default: 0.34
        }
    }

    private static func currentPosition(_ latitude: Double, _ longitude: Double) -> Sky.Position {
        #if DEBUG
        // `-skyAltitude -5` puts the app in blue hour at two in the afternoon. Twilight is
        // twenty minutes a day; without this it is not something anyone will check.
        if DemoSeed.skyAltitude != nil || DemoSeed.skyAzimuth != nil {
            let real = Sky.position(latitude: latitude, longitude: longitude)
            return Sky.Position(
                altitude: DemoSeed.skyAltitude ?? real.altitude,
                azimuth: DemoSeed.skyAzimuth ?? real.azimuth
            )
        }
        #endif
        return Sky.position(latitude: latitude, longitude: longitude)
    }
}
