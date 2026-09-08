import SwiftUI
import MapLibre
import CoreLocation
import ChinGoDesign

/// One friend, somewhere on the planet.
struct GlobePin: Identifiable, Equatable {
    let id: String
    let handle: String
    let coordinate: CLLocationCoordinate2D
    /// Seconds since the fix. Shown, never hidden — a dot with no age on it reads as "now",
    /// and it usually is not.
    let age: TimeInterval
    let accent: Int

    /// Equality is about what is drawn, and `age` deliberately is not part of it.
    ///
    /// It is derived from `Date.now` every time the list is rebuilt, so including it means two
    /// identical pins are never equal and anything keyed on "did this change" fires on every
    /// frame. That is what was rewriting the map source sixty times a second and, because
    /// writing a shape onto a source built with features throws its features away, leaving a
    /// correct layer over an empty source with nothing logged anywhere.
    static func == (a: GlobePin, b: GlobePin) -> Bool {
        a.id == b.id
            && a.accent == b.accent
            && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude
    }
}

/// The planet, with the people who agreed to be on it.
///
/// The same basemap and the same style as the street map, just pulled all the way out. That is
/// not laziness — at world zoom the style resolves to almost nothing, because OpenMapTiles
/// carries only Natural Earth ocean and ice below zoom 7. So the continents come out as the
/// background green and the sea as the water blue, which is the app's own palette drawing a
/// toy globe for free. Loading a second style to achieve that would have been work spent
/// arriving back where we started.
///
/// Flat and north-up, unlike the street map. A raked camera exists there to put you inside the
/// street; there is no inside to be on a planet, and a pitched world map is just a world map
/// you have to think about.
///
/// ## Known broken: the friend pins do not draw
///
/// The basemap, the camera, the fit and the tap target are all correct. The source is in the
/// style, both layers are in the style, `source.shape` reports the right feature count, and
/// `visibleFeatures` returns zero. Nothing is logged anywhere.
///
/// Ruled out, each by a separate run on device:
///
/// - **The data.** An identical `MLNCircleStyleLayer` over its own source, built from this
///   view's own `features()` in this same callback, draws both pins exactly where it should.
///   So the coordinates, the attributes and the feature objects are all fine.
/// - **Symbol-specific problems.** A lone circle layer at radius 14 on the shared source draws
///   nothing either, so it is not glyphs, fonts, icon registration or label collision.
/// - **`id` as an attribute key.** Renamed to `friend`; no change.
/// - **Timing.** Applying inside `didFinishLoading`, one run loop later, and from
///   `updateUIView` after an explicit `ready` bump all behave the same.
/// - **Construction style.** Built with `features:` and built with `shape: nil` then assigned
///   both fail, though mixing the two is separately wrong -- writing `shape` onto a source
///   constructed with `features:` discards them.
///
/// The remaining asymmetry between the working probe and this is that the probe's source is
/// never referenced again after construction. That points at something holding or mutating
/// `self.source`, and I have not found it. Everything else on this screen works, so it is
/// committed rather than reverted -- but the map is empty until this is solved, and nothing
/// here should be read as finished.
struct GlobeMap: UIViewRepresentable {
    var pins: [GlobePin]
    var accent: Accent
    /// Bumped by the caller to re-frame the view on everybody.
    var fitToken: Int
    /// Bumped by *this* view once its style has loaded.
    ///
    /// Every mutation of the source has to happen from `updateUIView`, never from inside the
    /// style-load callback -- that is the pattern the street map uses and the only one that
    /// renders. But this screen has no animation loop, so nothing would call `updateUIView`
    /// again after the style arrives and the source would stay empty forever. Writing through
    /// a binding makes SwiftUI schedule exactly one more update, which is all it needs.
    @Binding var ready: Int
    var onSelect: (GlobePin) -> Void

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: MapStyle.url(for: accent))
        map.delegate = context.coordinator
        map.logoView.isHidden = false
        map.attributionButton.isHidden = false
        map.compassView.isHidden = true
        map.minimumZoomLevel = 0.6
        map.maximumZoomLevel = 12
        map.setCenter(CLLocationCoordinate2D(latitude: 20, longitude: 0), zoomLevel: 1.1, animated: false)
        map.backgroundColor = UIColor(MapStyle.ground(for: accent))

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.tapped(_:))
        )
        map.addGestureRecognizer(tap)
        return map
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
        var parent: GlobeMap
        var source: MLNShapeSource?
        var lastFit = Int.min


        init(_ parent: GlobeMap) { self.parent = parent }

        func update(_ parent: GlobeMap) { self.parent = parent }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            for (name, image) in BearIcons.all {
                style.setImage(image, forName: name)
            }

            let source = MLNShapeSource(identifier: "globe-friends", shape: nil, options: nil)
            style.addSource(source)
            self.source = source

            // The exact point, under the bear. A billboard is anchored at its feet and read
            // as "around here"; the dot is what says "there".
            let dot = MLNCircleStyleLayer(identifier: "globe-friend-dots", source: source)
            dot.circleRadius = NSExpression(forConstantValue: 5)
            dot.circleColor = NSExpression(forConstantValue: UIColor(Ink.text))
            dot.circleStrokeWidth = NSExpression(forConstantValue: 2)
            dot.circleStrokeColor = NSExpression(forConstantValue: UIColor(Ink.groundRaised))
            style.addLayer(dot)

            let pins = MLNSymbolStyleLayer(identifier: "globe-friend-pins", source: source)
            pins.iconImageName = NSExpression(forKeyPath: "icon")
            pins.iconAnchor = NSExpression(forConstantValue: "bottom")
            pins.iconAllowsOverlap = NSExpression(forConstantValue: true)
            // A symbol is icon *and* label, and by default a label that cannot be placed takes
            // its icon down with it. The basemap's country names are dense at this zoom, so
            // without these every handle would collide with one and take its bear with it.
            pins.textAllowsOverlap = NSExpression(forConstantValue: true)
            pins.textOptional = NSExpression(forConstantValue: true)
            // Constant, not zoom-interpolated. On a world map a bear that grows as you zoom
            // turns into a continent-sized bear over Europe before you have read the handle.
            pins.iconScale = NSExpression(forConstantValue: 0.13)
            pins.text = NSExpression(forKeyPath: "handle")
            pins.textFontSize = NSExpression(forConstantValue: 11)
            pins.textColor = NSExpression(forConstantValue: UIColor(Ink.text))
            pins.textHaloColor = NSExpression(forConstantValue: UIColor(Ink.groundRaised))
            pins.textHaloWidth = NSExpression(forConstantValue: 2)
            pins.textAnchor = NSExpression(forConstantValue: "top")
            pins.textTranslation = NSExpression(forConstantValue: NSValue(cgVector: CGVector(dx: 0, dy: 2)))
            style.addLayer(pins)


            // Out of the callback, both of them. A shape written here never reaches the
            // renderer -- the source stays in the style, the layers stay correct,
            // `visibleFeatures` returns zero and nothing is logged anywhere -- and a
            // `setVisibleCoordinateBounds` against a not-yet-laid-out view silently does
            // nothing, which left the camera on its opening frame with half the friends off
            // the right-hand edge.
            DispatchQueue.main.async { [weak mapView] in
                guard let mapView else { return }
                self.parent.ready += 1
                self.fit(mapView)
            }
        }

        func features() -> [MLNShape & MLNFeature] {
            parent.pins.map { pin in
                    let point = MLNPointFeature()
                    point.coordinate = pin.coordinate
                    point.attributes = [
                        "icon": BearIcons.name(accent: pin.accent, phase: nil),
                        "handle": pin.handle,
                        // Not "id". That key is reserved for the feature identifier, and a
                        // feature carrying its own conflicts with it -- the source accepts the
                        // shape, the style reports the layers, and nothing is ever drawn.
                        "friend": pin.id,
                    ]
                return point
            }
        }

        func apply(to mapView: MLNMapView) {
            source?.shape = MLNShapeCollectionFeature(shapes: features())
        }

        /// Frames everybody, or sits over the Atlantic if there is nobody to frame.
        func fit(_ mapView: MLNMapView) {
            let coordinates = parent.pins.map(\.coordinate)
            guard !coordinates.isEmpty else { return }

            if coordinates.count == 1, let only = coordinates.first {
                mapView.setCenter(only, zoomLevel: 4, animated: true)
                return
            }

            var bounds = MLNCoordinateBounds(sw: coordinates[0], ne: coordinates[0])
            for c in coordinates.dropFirst() {
                bounds.sw = CLLocationCoordinate2D(
                    latitude: min(bounds.sw.latitude, c.latitude),
                    longitude: min(bounds.sw.longitude, c.longitude)
                )
                bounds.ne = CLLocationCoordinate2D(
                    latitude: max(bounds.ne.latitude, c.latitude),
                    longitude: max(bounds.ne.longitude, c.longitude)
                )
            }
            // Generous padding. A bounding box fitted tightly puts the outermost person's
            // bear half off the edge, because the box is fitted to the point and the bear is
            // drawn above it.
            mapView.setVisibleCoordinateBounds(
                bounds,
                edgePadding: UIEdgeInsets(top: 90, left: 60, bottom: 120, right: 60),
                animated: true
            )
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            // A generous square rather than the exact point: these are small icons on a world
            // map and a finger is not a cursor.
            let box = CGRect(x: point.x - 22, y: point.y - 30, width: 44, height: 44)
            let hits = mapView.visibleFeatures(in: box, styleLayerIdentifiers: ["globe-friend-pins"])
            guard let id = hits.compactMap({ $0.attribute(forKey: "friend") as? String }).first,
                  let pin = parent.pins.first(where: { $0.id == id })
            else { return }
            parent.onSelect(pin)
        }
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.update(self)
        context.coordinator.apply(to: map)

        if context.coordinator.lastFit != fitToken {
            context.coordinator.lastFit = fitToken
            context.coordinator.fit(map)
        }
    }
}
