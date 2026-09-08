import Testing
import Foundation
@testable import ChinGoEngine

@Suite("Globe sharing — the consent gate")
struct GlobeSharingTests {

    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private let both = GlobeSharing.Grant(iShare: true, theyShare: true)

    private func look(
        _ grant: GlobeSharing.Grant,
        enabled: Bool = true,
        paused: Bool = false,
        agoHours: Double = 1
    ) -> GlobeSharing.Visibility {
        GlobeSharing.visibility(
            of: grant,
            globeEnabled: enabled,
            sharingPaused: paused,
            latitude: 37.77,
            longitude: -122.41,
            updatedAt: now.addingTimeInterval(-agoHours * 3600),
            now: now
        )
    }

    @Test("A new friend shares nothing in either direction")
    func offByDefault() {
        #expect(GlobeSharing.Grant.none.iShare == false)
        #expect(GlobeSharing.Grant.none.theyShare == false)
        #expect(look(.none) == .quiet)
    }

    @Test("Both grants are needed, and neither implies the other")
    func bothSidesRequired() {
        #expect(look(GlobeSharing.Grant(iShare: true, theyShare: false)) == .quiet)
        #expect(look(GlobeSharing.Grant(iShare: false, theyShare: true)) == .quiet)
        #expect(look(both) != .quiet)
    }

    @Test("Switching your own sharing off closes the window both ways")
    func noOneWayWindow() {
        // The line that decides whether this is a mutual feature or a tracking feature.
        #expect(GlobeSharing.canSee(both, globeEnabled: false, sharingPaused: false) == false)
        #expect(GlobeSharing.canSee(both, globeEnabled: true, sharingPaused: true) == false)
        #expect(GlobeSharing.canBeSeenBy(both, globeEnabled: true, sharingPaused: true) == false)
    }

    @Test("A paused friend is indistinguishable from one whose phone is off")
    func pausingIsDeniable() {
        // The whole safety argument. If these two ever produce different values, stopping
        // sharing becomes an action with a social cost and the feature stops being optional.
        let paused = look(both, paused: true)
        let noPosition = GlobeSharing.visibility(
            of: both, globeEnabled: true, sharingPaused: false,
            latitude: nil, longitude: nil, updatedAt: nil, now: now
        )
        let revoked = look(GlobeSharing.Grant(iShare: true, theyShare: false))
        let stale = look(both, agoHours: 99)

        #expect(paused == .quiet)
        #expect(noPosition == .quiet)
        #expect(revoked == .quiet)
        #expect(stale == .quiet)
        #expect(paused == noPosition)
        #expect(paused == revoked)
        #expect(paused == stale)
    }

    @Test("Quiet carries no reason")
    func quietSaysNothing() {
        // A case with an associated reason can be rendered, logged or synced, and any of
        // those leaks what the test above protects. This asserts the shape of the type.
        #expect(GlobeSharing.Visibility.quiet == .quiet)
    }

    @Test("A position goes stale rather than lingering")
    func freshnessWindow() {
        #expect(look(both, agoHours: 5.9) != .quiet)
        #expect(look(both, agoHours: 6.1) == .quiet)
    }

    @Test("A visible friend comes with how old the fix is")
    func ageTravelsWithPosition() {
        // So the globe can say "about an hour ago" rather than implying it is live. A dot
        // with no age on it is read as now, and it usually is not.
        guard case let .somewhere(lat, lon, age) = look(both, agoHours: 2) else {
            Issue.record("expected a position")
            return
        }
        #expect(lat == 37.77)
        #expect(lon == -122.41)
        #expect(abs(age - 7200) < 1)
    }
}
