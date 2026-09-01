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
}
