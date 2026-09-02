import Testing
import SwiftUI
@testable import ChinGoDesign

/// The token sets exist to stop a view inventing values. These assert the sets themselves
/// stay coherent — a spacing scale with two identical steps, or a radius tier that does not
/// grow with element size, quietly reintroduces the uniformity the tokens were added to
/// prevent.
@Suite("Design tokens")
struct TokenTests {

    @Test("Spacing sits on the 4pt grid")
    func spacingOnGrid() {
        let scale = [Space.hair, Space.tight, Space.snug, Space.step,
                     Space.inset, Space.margin, Space.section]
        for value in scale {
            #expect(value.truncatingRemainder(dividingBy: 4) == 0, "\(value) is off the 4pt grid")
        }
    }

    @Test("Spacing steps are distinct and ascending")
    func spacingAscends() {
        let scale = [Space.hair, Space.tight, Space.snug, Space.step,
                     Space.inset, Space.margin, Space.section]
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count, "two spacing tokens share a value")
    }

    @Test("Radius grows with the size of the thing")
    func radiusAscends() {
        #expect(Radius.control < Radius.card)
        #expect(Radius.card < Radius.surface)
    }

    @Test("Elevation blur and offset grow together")
    func elevationScales() {
        // A shadow whose blur grows without its offset reads as a glow rather than height.
        let tiers = [Elevation.low, Elevation.float, Elevation.card, Elevation.sheet]
        for (lower, higher) in zip(tiers, tiers.dropFirst()) {
            #expect(higher.radius > lower.radius)
            #expect(higher.y > lower.y)
        }
    }

    @Test("The hit target clears Apple's minimum")
    func hitTarget() {
        #expect(Space.minimumHitTarget >= 44)
    }
}
