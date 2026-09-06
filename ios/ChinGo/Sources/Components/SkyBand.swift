import SwiftUI
import ChinGoDesign

/// The sky, tracking the real sun where the player actually is.
///
/// **What this honestly is.** `CameraMath.pitchRange` caps the rake at 70 degrees precisely so
/// the horizon never comes into view -- past it the tiles run out and you can see the edge of
/// the world. So there is no horizon here to hang a skybox on, and this does not pretend
/// otherwise: it is atmospheric haze thickening toward the far edge of the map. That is the
/// read Pokemon GO gets from its own sky anyway, and it is the honest thing to build against
/// a camera that deliberately cannot see the horizon.
///
/// **On the fade.** Everything printed on the world -- pills, cards, the bar, the puck -- is
/// hard-edged and zero-blur, and stays that way. This is not printed on the world; it is the
/// world. A sky with a hard bottom edge would be a coloured rectangle stuck to the screen.
struct SkyBand: View {
    var latitude: Double
    var longitude: Double

    /// Sun altitude in degrees. Seeded synchronously so the first frame is already correct
    /// rather than flashing a default sky and correcting a moment later.
    @State private var altitude: Double

    /// How much of the screen the haze reaches down. Far enough to sit behind the top chrome,
    /// not so far that it starts tinting the ground the player is standing on.
    private static let reach: CGFloat = 0.38

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        _altitude = State(initialValue: SkyBand.currentAltitude(latitude, longitude))
    }

    var body: some View {
        let band = Sky.band(atAltitude: altitude)

        GeometryReader { geo in
            LinearGradient(
                colors: [band.high, band.low],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: geo.size.height * Self.reach)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.82), location: 0.5),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(Motion.reduceMotion ? nil : .easeInOut(duration: 1.2), value: altitude)
        .task(id: "\(latitude),\(longitude)") {
            // The sun moves a quarter of a degree a minute, against a palette whose narrowest
            // keyframe band is two degrees wide. A minute between samples is invisible, and
            // recomputing per frame would be arithmetic nobody asked for.
            while !Task.isCancelled {
                altitude = Self.currentAltitude(latitude, longitude)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private static func currentAltitude(_ latitude: Double, _ longitude: Double) -> Double {
        #if DEBUG
        // `-skyAltitude -5` puts the app in blue hour at two in the afternoon. Twilight is
        // twenty minutes a day; without this it is not something anyone will check.
        if let forced = DemoSeed.skyAltitude { return forced }
        #endif
        return Sky.altitude(latitude: latitude, longitude: longitude)
    }
}
