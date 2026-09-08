import Testing
@testable import ChinGoEngine

@Suite("Presence — the safety gate")
struct PresenceTests {

    @Test("A thin cell reveals nothing")
    func thinCellSuppressed() {
        let q = Presence.CellQuery(
            occupants: Presence.kAnonymityFloor - 1,
            viewerIsDiscoverable: true,
            hasMutualHandshake: false
        )
        #expect(Presence.visibility(for: q) == .suppressed)
    }

    @Test("Discovery is reciprocal — a hidden viewer cannot see either")
    func ghostCannotWatch() {
        let q = Presence.CellQuery(occupants: 500, viewerIsDiscoverable: false, hasMutualHandshake: false)
        #expect(Presence.visibility(for: q) == .suppressed)
    }

    @Test("A crowded cell shows a bubble, capped")
    func crowdedCellShowsCappedCount() {
        let q = Presence.CellQuery(occupants: 5_000, viewerIsDiscoverable: true, hasMutualHandshake: false)
        #expect(Presence.visibility(for: q) == .crowd(count: Presence.crowdCeiling))
    }

    @Test("Only a mutual handshake outranks the floor")
    func mutualOutranksFloor() {
        let q = Presence.CellQuery(occupants: 1, viewerIsDiscoverable: false, hasMutualHandshake: true)
        #expect(Presence.visibility(for: q) == .mutual)
    }

    @Test("Teleporting is implausible, commuting is not")
    func plausibility() {
        // 400 km in a minute.
        #expect(Plausibility.isPlausible(metresMoved: 400_000, secondsElapsed: 60) == false)
        // 30 km in half an hour — a train.
        #expect(Plausibility.isPlausible(metresMoved: 30_000, secondsElapsed: 1_800) == true)
        #expect(Plausibility.isPlausible(metresMoved: 10, secondsElapsed: 0) == false)
    }

    // MARK: - Live positions

    /// Everything switched on: the one arrangement that draws a person where they stand.
    private func open(
        viewer: Bool = true,
        subject: Bool = true,
        metres: Double = 50,
        occupants: Int = Presence.kAnonymityFloor,
        handshake: Bool = false,
        wasVisible: Bool = false
    ) -> Presence.LiveQuery {
        Presence.LiveQuery(
            viewerIsDiscoverable: viewer,
            subjectIsDiscoverable: subject,
            metresApart: metres,
            cellOccupants: occupants,
            hasMutualHandshake: handshake,
            wasVisible: wasVisible
        )
    }

    @Test("A person is drawn precisely only when every gate is open")
    func liveNeedsEveryGate() {
        #expect(Presence.livePosition(for: open()) == .precise)
    }

    @Test("Live visibility is reciprocal in both directions")
    func liveIsReciprocal() {
        // A hidden viewer sees nobody, however crowded the street.
        #expect(Presence.livePosition(for: open(viewer: false, occupants: 500)) == .suppressed)
        // A hidden person is seen by nobody, however findable the viewer is.
        #expect(Presence.livePosition(for: open(subject: false, occupants: 500)) == .suppressed)
    }

    @Test("A thin cell hides a person exactly as it hides a bubble")
    func liveKeepsTheFloor() {
        #expect(Presence.livePosition(for: open(occupants: Presence.kAnonymityFloor - 1)) == .suppressed)
        #expect(Presence.livePosition(for: open(occupants: Presence.kAnonymityFloor)) == .precise)
    }

    @Test("Somebody appears at the discovery ring and stays until the release ring")
    func liveHysteresis() {
        let inRing = Presence.discoveryRadiusMetres
        let past = Presence.discoveryRadiusMetres + 1
        let stillIn = Presence.releaseRadiusMetres
        let gone = Presence.releaseRadiusMetres + 1

        // Not yet drawn: the discovery radius decides.
        #expect(Presence.livePosition(for: open(metres: inRing)) == .precise)
        #expect(Presence.livePosition(for: open(metres: past)) == .suppressed)
        // Already drawn: the same distance keeps them, up to the release radius.
        #expect(Presence.livePosition(for: open(metres: past, wasVisible: true)) == .precise)
        #expect(Presence.livePosition(for: open(metres: stillIn, wasVisible: true)) == .precise)
        #expect(Presence.livePosition(for: open(metres: gone, wasVisible: true)) == .suppressed)
    }

    @Test("A handshake outranks every live gate")
    func liveHandshakeOutranks() {
        let q = open(viewer: false, subject: false, metres: 5_000, occupants: 1, handshake: true)
        #expect(Presence.livePosition(for: q) == .precise)
    }

    @Test("A distance that is not a distance draws nothing")
    func liveRejectsBrokenDistance() {
        // NaN compares false against everything, which would let it through a naive `<=`.
        #expect(Presence.livePosition(for: open(metres: .nan)) == .suppressed)
        #expect(Presence.livePosition(for: open(metres: .infinity)) == .suppressed)
        #expect(Presence.livePosition(for: open(metres: -1)) == .suppressed)
    }

    @Test("The radii nest, and discovery is the memory radius")
    func liveRadiiNest() {
        #expect(Presence.interactionRadiusMetres < Presence.discoveryRadiusMetres)
        #expect(Presence.discoveryRadiusMetres < Presence.releaseRadiusMetres)
        #expect(Presence.discoveryRadiusMetres == Geo.memoryRadiusMetres)
    }
}
