import Testing
import SwiftUI
@testable import ChinGoDesign

/// The map palette is measured, not chosen, so these lock the relationships the measurements
/// are *about* rather than the hexes themselves. A future retune is free to move every value;
/// it is not free to make a park the same lightness as the ground, or the road the same hue
/// family as nothing.
@Suite("Map palette")
struct MapPaletteTests {

    private func parts(_ colour: Color) -> (r: Double, g: Double, b: Double) {
        let c = colour.resolve(in: EnvironmentValues())
        return (Double(c.red), Double(c.green), Double(c.blue))
    }

    /// Not WCAG luminance -- plain HSL lightness, which is what "40 points darker" means when
    /// a palette is discussed.
    private func lightness(_ colour: Color) -> Double {
        let (r, g, b) = parts(colour)
        return (max(r, g, b) + min(r, g, b)) / 2
    }

    private func saturation(_ colour: Color) -> Double {
        let (r, g, b) = parts(colour)
        let (hi, lo) = (max(r, g, b), min(r, g, b))
        guard hi != lo else { return 0 }
        let l = (hi + lo) / 2
        return (hi - lo) / (l > 0.5 ? (2 - hi - lo) : (hi + lo))
    }

    /// How much colour is actually in it, regardless of how light it is. HSL saturation is
    /// the wrong tool near white -- #EAF4F4 is a near-neutral by eye and scores 31% on it,
    /// because at L94% the denominator has collapsed. Chroma does not have that failure.
    private func chroma(_ colour: Color) -> Double {
        let (r, g, b) = parts(colour)
        return max(r, g, b) - min(r, g, b)
    }

    /// Degrees, 0 = red, 120 = green.
    private func hue(_ colour: Color) -> Double {
        let (r, g, b) = parts(colour)
        let (hi, lo) = (max(r, g, b), min(r, g, b))
        guard hi != lo else { return 0 }
        let d = hi - lo
        let h: Double
        switch hi {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        return h * 60
    }

    @Test("A park is a step down from the ground, not a nudge")
    func parksSeparate() {
        // The reference runs ground L78% against park L37%. Anything under about fifteen
        // points reads as a rendering artefact on a field that is already green.
        #expect(lightness(Ink.mapLand) - lightness(Ink.mapPark) > 0.15)
        #expect(lightness(Ink.mapPark) > lightness(Ink.mapParkDeep))
    }

    @Test("Land parcels are texture, not classification")
    func parcelsAreQuiet() {
        // The opposite constraint to the one above: parcels have to be *nearly* the ground.
        #expect(abs(lightness(Ink.mapLand) - lightness(Ink.mapLandParcel)) < 0.06)
        #expect(abs(hue(Ink.mapLand) - hue(Ink.mapLandParcel)) < 8)
    }

    @Test("The road is the ground, darker and drained")
    func roadSharesTheGroundsHue() {
        // Not neutral grey. A true grey road on a green field reads as pasted on; the
        // reference keeps the road in the ground's hue family and takes the saturation out.
        #expect(abs(hue(Ink.mapRoad) - hue(Ink.mapLand)) < 60)
        #expect(saturation(Ink.mapRoad) < saturation(Ink.mapLand))
        #expect(lightness(Ink.mapLand) - lightness(Ink.mapRoad) > 0.2)
    }

    @Test("The casing is the loudest thing on the ground")
    func casingCarries() {
        // It is what makes a road network read as one object. If it ever stops being much
        // lighter than the road it wraps, the ribbon stops having an edge.
        #expect(lightness(Ink.mapRoadCasing) - lightness(Ink.mapRoad) > 0.3)
        #expect(saturation(Ink.mapRoadCasing) > 0.5)
    }

    @Test("Paths read as a different surface, not a narrow road")
    func pathsAreNotRoads() {
        #expect(lightness(Ink.mapPath) > lightness(Ink.mapLand))
        #expect(chroma(Ink.mapPath) < 0.06)
    }

    @Test("The haze is lighter and paler than everything it sits between")
    func hazeIsTheLowContrastPart() {
        // The whole reason the reference's horizon looks clean: it is the *lowest*-contrast
        // part of the frame, not the highest. Sky above it and ground below it are both more
        // saturated and both darker.
        #expect(lightness(Ink.mapHaze) > lightness(Ink.mapLand))
        #expect(lightness(Ink.mapHaze) > lightness(Ink.mapWater))
        #expect(saturation(Ink.mapHaze) >= saturation(Ink.mapLand))
        #expect(lightness(Ink.mapHaze) > 0.85)
    }
}
