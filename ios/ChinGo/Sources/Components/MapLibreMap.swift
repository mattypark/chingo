import SwiftUI
import MapLibre
import CoreLocation
import ChinGoDesign

/// The real world.
///
/// Replaces the hand-drawn Canvas placeholder. Streets, buildings, parks and shops come from
/// OpenStreetMap through OpenFreeMap's free vector tiles, styled by `chingo-style.json` with
/// the same `Ink` tokens the chrome uses — the basemap and the interface floating above it
/// have to read as one product, not as an app sitting on top of somebody else's map.
///
/// **Why this wraps `MLNMapView` by hand** rather than using MapLibre's official SwiftUI DSL:
/// that package is pre-1.0 and its consumers pin it to `main`, so breaking API changes arrive
/// with no version to hold. This is about 100 lines and leaves one versioned dependency.
///
/// **Why it does not use MapLibre's own location tracking**: `LocationService` already owns
/// location for the whole app, including the coarsening that the privacy model depends on.
/// Two location sources would eventually disagree, and the one that disagrees silently is the
/// one that leaks. So the camera is driven from our coordinate, and MapLibre never starts a
/// `CLLocationManager` of its own.
struct MapLibreMap: UIViewRepresentable {
    @Environment(\.accent) private var accent

    /// Where to point the camera.
    var coordinate: CLLocationCoordinate2D
    /// Compass bearing the camera faces. Driven by `MapCamera`, which is either following
    /// the direction of travel or being dragged by the user.
    var bearing: CLLocationDirection
    /// How far back the camera is raked. 0 is a flat document; 60 is standing in a world.
    var pitch: CGFloat
    /// How close in. Converted to a camera altitude through MapLibre's own helper, because
    /// altitude and zoom are only equivalent at a given pitch and latitude — computing it by
    /// hand is how a camera ends up either underground or looking at the whole planet.
    var zoom: Double

    /// Everyone with a bear on the map, nearest last so the draw order is already right.
    var bears: [BearMark] = []

    /// The two ground rings, or nil before a position is known.
    var radar: RadarState?

    func makeUIView(context: Context) -> MLNMapView {
        // Not the bundled file directly: MapStyle corrects the palette the generated style
        // drifted from and washes the neutral family toward the player's accent.
        let map = MLNMapView(frame: .zero, styleURL: MapStyle.url(for: accent))
        context.coordinator.paintedAccent = accent.id

        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Our own puck is drawn on top, centred and fixed. MapLibre's blue dot would be a
        // second, slightly-disagreeing representation of the same fact.
        map.showsUserLocation = false
        map.userTrackingMode = .none

        // The player stays put and the world moves. That single decision is most of what
        // makes a map screen feel like a game rather than a navigation tool.
        // Every camera gesture is handled by MapCamera and applied through setCamera, so
        // MapLibre's own gesture recognisers are all off. Leaving them on means two things
        // driving one camera, which shows up as the view snapping back mid-drag.
        //
        // Rotation in particular has to be ours: MapLibre's built-in rotate is a two-finger
        // twist, and looking around should cost one thumb.
        map.allowsScrolling = false
        map.allowsRotating = false
        map.allowsTilting = false
        map.allowsZooming = false

        // MapLibre's own ceiling is 60 degrees, and CameraMath has always said 70. The two
        // never agreed, and MapLibre won silently -- every "raked all the way back" view in
        // this app was actually stopping at 60. Raised so the engine's range is reachable,
        // and so the horizon can come into view at all: the reason it was kept off screen
        // was that the tiles run out behind it, and there is a sky over there now.
        map.maximumPitch = 85

        map.compassView.isHidden = true
        map.logoView.isHidden = true
        // The attribution button stays. OpenStreetMap's licence requires credit, and it is
        // also the only affordance telling a curious user where the map came from.
        //
        // Lifted clear of HomeBar, which now spans the full width and buried it. A licence
        // notice hidden under the chrome is not a licence notice.
        map.attributionButton.tintColor = UIColor(Ink.textFaint)
        map.attributionButtonPosition = .bottomLeft
        map.attributionButtonMargins = CGPoint(x: Space.inset, y: 132)

        map.delegate = context.coordinator
        context.coordinator.aim = { map in camera(for: map, heading: bearing) }
        map.setCamera(camera(for: map, heading: bearing), animated: false)

        return map
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Keeps the camera the representable last asked for, and puts it back once the style is up.
    ///
    /// `MLNMapView` adopts the style's own default camera when the style finishes loading, and
    /// that lands well after `makeUIView` has already pointed the camera at the player --
    /// tiles come over the network. `chingo-style.json` declares no `center` or `zoom`, so the
    /// default it adopts is the whole planet at zoom 0.
    ///
    /// `updateUIView` cannot rescue it either: it only fires when one of the four inputs
    /// changes, and until a fix lands `coordinateOrFallback` returns the same constant every
    /// time. Without a fix -- the simulator always, a real device indoors, anyone who declined
    /// location -- the map opens over the Atlantic and stays there. Re-aiming on
    /// `didFinishLoading` is what makes it open where the player is standing.
    final class Coordinator: NSObject, MLNMapViewDelegate {
        /// `MLNMapView.zoomLevel` is derived from altitude and drifts by a hair, so comparing
        /// against it directly reports a change every frame.
        var lastZoom: Double = .nan

        /// The camera most recently asked for, replayed once the style is ready.
        var aim: ((MLNMapView) -> MLNMapCamera)?

        /// Which accent the loaded style was painted for. A style reload is expensive and
        /// clobbers the camera, so it happens only when the colour genuinely changed.
        var paintedAccent: Int?

        /// The source the bear layers read. Held so `updateUIView` can push new positions
        /// without rebuilding the layers.
        var bearSource: MLNShapeSource?
        var radarSource: MLNShapeSource?
        /// The rings' own layers, kept so the hidden state can restyle them without a reload.
        var radarLines: [MLNLineStyleLayer] = []

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            installRadarLayers(into: style)
            installBearLayers(into: style)
            if let aim { mapView.setCamera(aim(mapView), animated: false) }
        }

        /// The two rings, as real geometry in real coordinates.
        ///
        /// Inserted *below* the first label layer so street names stay readable over them --
        /// a ring painted over its own street is a ring you cannot navigate by.
        func installRadarLayers(into style: MLNStyle) {
            let source = MLNShapeSource(identifier: "radar", shape: nil, options: nil)
            style.addSource(source)
            radarSource = source

            // Line width in points, not metres, so the stroke stays the same weight on screen
            // while the ring itself stays true to the ground. That is the combination the
            // sticker language wants: a constant heavy outline around a shape that is
            // genuinely out there in the world.
            func ring(_ identifier: String, width: CGFloat, colour: UIColor) -> MLNLineStyleLayer {
                let layer = MLNLineStyleLayer(identifier: identifier, source: source)
                layer.predicate = NSPredicate(format: "ring == %@", identifier)
                layer.lineColor = NSExpression(forConstantValue: colour)
                layer.lineWidth = NSExpression(forConstantValue: width)
                layer.lineCap = NSExpression(forConstantValue: "round")
                layer.lineJoin = NSExpression(forConstantValue: "round")
                return layer
            }

            // The outer ring is the quieter one: it marks where people stop existing, which
            // is information rather than an invitation. The inner one is where you can act,
            // so it carries the accent.
            let discovery = ring("discovery", width: 2.5, colour: UIColor.white.withAlphaComponent(0.85))
            let interaction = ring("interaction", width: 4, colour: UIColor(Ink.text).withAlphaComponent(0.55))
            radarLines = [discovery, interaction]

            // Below the first symbol layer, which is where labels start.
            let firstLabel = style.layers.first { $0 is MLNSymbolStyleLayer }
            for layer in radarLines {
                if let firstLabel {
                    style.insertLayer(layer, below: firstLabel)
                } else {
                    style.addLayer(layer)
                }
            }
        }

        /// Two symbol layers: a shadow lying on the road, and a bear standing up off it.
        ///
        /// Rendered by MapLibre rather than as a SwiftUI overlay, and that is the whole
        /// design. Inside the map's own frame there is no projection to synchronise and no
        /// second renderer to fall a frame behind, so the bears cannot swim against the map
        /// during a pan. It also hands over two things for free that would otherwise be work:
        /// upright billboarding on a pitched camera, and correct depth sorting between bears.
        func installBearLayers(into style: MLNStyle) {
            for (name, image) in BearIcons.all {
                style.setImage(image, forName: name)
            }

            let source = MLNShapeSource(identifier: "bears", shape: nil, options: nil)
            style.addSource(source)
            bearSource = source

            // The shadow is pitch-aligned to the *map*, so it lies flat on the road. The bear
            // is aligned to the viewport, so it stands up and faces you. That split is what
            // sells a flat image as something standing in the world, and it is the single
            // highest-value line in this file.
            let shadow = MLNSymbolStyleLayer(identifier: "bear-shadows", source: source)
            shadow.iconImageName = NSExpression(forConstantValue: BearIcons.shadowName)
            shadow.iconPitchAlignment = NSExpression(forConstantValue: "map")
            shadow.iconRotationAlignment = NSExpression(forConstantValue: "map")
            shadow.iconAnchor = NSExpression(forConstantValue: "center")
            shadow.iconAllowsOverlap = NSExpression(forConstantValue: true)
            shadow.iconScale = iconScale(0.105)
            style.addLayer(shadow)

            let bear = MLNSymbolStyleLayer(identifier: "bear-avatars", source: source)
            bear.iconImageName = NSExpression(forKeyPath: "icon")
            bear.iconPitchAlignment = NSExpression(forConstantValue: "viewport")
            bear.iconRotationAlignment = NSExpression(forConstantValue: "viewport")
            // Feet on the coordinate, not the middle of the body.
            bear.iconAnchor = NSExpression(forConstantValue: "bottom")
            bear.iconAllowsOverlap = NSExpression(forConstantValue: true)
            // Painter's algorithm by screen Y, so a nearer bear covers a further one without
            // anybody sorting anything.
            bear.symbolZOrder = NSExpression(forConstantValue: "viewport-y")
            bear.iconScale = iconScale(0.17)
            style.addLayer(bear)
        }

        /// Keeps a bear the same size in the world rather than the same size on screen, so
        /// walking away from someone makes them smaller.
        ///
        /// The numbers look small because the icons are rendered at device scale -- a 192pt
        /// bear is 576 actual pixels on a 3x phone, and MapLibre scales the pixels. Tuned by
        /// looking at it: the first pass put a bear a quarter of the screen tall.
        private func iconScale(_ base: Double) -> NSExpression {
            NSExpression(
                format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'exponential', 2, %@)",
                [16: base * 0.35, 19: base]
            )
        }
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let lastZoom = context.coordinator.lastZoom
        context.coordinator.lastZoom = zoom
        context.coordinator.aim = { map in camera(for: map, heading: bearing) }

        if let radar {
            let rings: [(String, Double)] = [
                ("discovery", Radar.discoveryMetres),
                ("interaction", Radar.interactionMetres),
            ]
            context.coordinator.radarSource?.shape = MLNShapeCollectionFeature(
                shapes: rings.map { name, metres in
                    var points = Radar.ring(around: radar.centre, metres: metres)
                    let line = MLNPolylineFeature(coordinates: &points, count: UInt(points.count))
                    line.attributes = ["ring": name]
                    return line
                }
            )
            // Hidden dashes the rings and dims them rather than removing them. Somebody who
            // has switched themselves off still needs to see the shape of what they switched
            // off -- an exposure boundary you cannot see is one you cannot reason about, and
            // the state that hides its own indicator is the one people stop trusting.
            for layer in context.coordinator.radarLines {
                layer.lineDashPattern = radar.discoverable
                    ? nil
                    : NSExpression(forConstantValue: [2, 2])
                layer.lineOpacity = NSExpression(forConstantValue: radar.discoverable ? 1.0 : 0.4)
            }
        }

        context.coordinator.bearSource?.shape = MLNShapeCollectionFeature(
            shapes: bears.map { mark in
                let point = MLNPointFeature()
                point.coordinate = mark.coordinate
                point.attributes = ["icon": mark.icon]
                return point
            }
        )

        if context.coordinator.paintedAccent != accent.id {
            context.coordinator.paintedAccent = accent.id
            // Reloading throws the camera back to the style's default; didFinishLoading puts
            // it where the player is again.
            map.styleURL = MapStyle.url(for: accent)
        }
        // A drag must land on the same frame it happens on, or looking around feels like
        // steering a boat. Position changes still ease, because a camera that snaps to every
        // GPS fix reads as jitter even when the fixes are good.
        // Any live gesture lands on the frame it happens on. Easing a pinch makes the map
        // feel like it is catching up with the fingers rather than following them.
        let gesturing = abs(map.camera.heading - bearing) > 0.5
            || abs(map.camera.pitch - pitch) > 0.5
            || abs(lastZoom - zoom) > 0.001
        map.setCamera(
            camera(for: map, heading: bearing),
            withDuration: gesturing ? 0 : 0.85,
            animationTimingFunction: nil
        )
    }

    private func camera(for map: MLNMapView, heading: CLLocationDirection) -> MLNMapCamera {
        // The view can be zero-sized on the very first layout pass, and an altitude derived
        // from a zero size is meaningless — so fall back to the screen until it isn't.
        let size = map.bounds.size == .zero ? UIScreen.main.bounds.size : map.bounds.size
        let altitude = MLNAltitudeForZoomLevel(zoom, pitch, coordinate.latitude, size)
        return MLNMapCamera(
            lookingAtCenter: coordinate,
            altitude: altitude,
            pitch: pitch,
            heading: heading
        )
    }
}


/// One bear, ready to draw.
///
/// Deliberately not `NearbyPerson`: this is the render-side shape, and keeping it separate
/// means the walk phase can tick at ten times a second without anything believing a person's
/// identity changed.
struct BearMark: Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let icon: String

    // CLLocationCoordinate2D is not Equatable, so there is no synthesised conformance to have.
    static func == (a: BearMark, b: BearMark) -> Bool {
        a.id == b.id
            && a.icon == b.icon
            && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude
    }
}
