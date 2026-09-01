import Foundation

/// The rule that decides whether another human being is allowed to appear on your screen.
///
/// This is the most safety-critical file in the app. Zenly is dead, Life360 spent 2025 in
/// court over location data and stalking, and Instagram Map drew a letter from 37 state
/// attorneys general demanding minors be blocked from location sharing. The difference
/// between this app and those is enforced here and in the RLS policies — not in the UI.
///
/// Three rules, in order:
///   1. Nobody's precise position is ever exposed. Everything resolves to a cell centroid.
///   2. A cell reveals nothing until at least `k` people occupy it.
///   3. Discovery is opt-in per session, so being findable is something you switch on
///      when you go out, not a property of owning the app.
public enum Presence {

    /// Minimum occupants before a cell may be shown at all.
    ///
    /// Five, not three: below that the consecutive-disclosure attack gets cheap. An
    /// observer who watches a cell go from k to k−1 as one person leaves can re-identify
    /// them, and the smaller k is, the fewer observations that takes.
    public static let kAnonymityFloor = 5

    /// Never report a count that itself leaks. Above the ceiling the UI says "lots".
    public static let crowdCeiling = 50

    public enum CellVisibility: Sendable, Equatable {
        /// Too few people, or the viewer is not sharing. Draw nothing at all — not a
        /// greyed-out marker, not a "hidden" badge. An absence that is rendered is still
        /// a signal.
        case suppressed
        /// Safe to draw a crowd bubble at the cell centroid with this many occupants.
        case crowd(count: Int)
        /// The viewer and this person have a live mutual handshake, so they may see each
        /// other properly. This is the only path to a precise position, ever.
        case mutual
    }

    public struct CellQuery: Sendable {
        public let occupants: Int
        public let viewerIsDiscoverable: Bool
        public let hasMutualHandshake: Bool

        public init(occupants: Int, viewerIsDiscoverable: Bool, hasMutualHandshake: Bool) {
            self.occupants = occupants
            self.viewerIsDiscoverable = viewerIsDiscoverable
            self.hasMutualHandshake = hasMutualHandshake
        }
    }

    public static func visibility(for q: CellQuery) -> CellVisibility {
        // A mutual handshake is an explicit, two-sided, in-the-moment agreement and is the
        // only thing that outranks the floor.
        if q.hasMutualHandshake { return .mutual }
        // Discovery is reciprocal: if you are not findable, you do not get to find.
        // Without this, "ghost mode" becomes a one-way surveillance seat.
        guard q.viewerIsDiscoverable else { return .suppressed }
        guard q.occupants >= kAnonymityFloor else { return .suppressed }
        return .crowd(count: min(q.occupants, crowdCeiling))
    }
}

/// A physical-plausibility check on a claimed position.
///
/// Cheap, universal, and not a security boundary — it catches a spoofer who teleports,
/// not one who walks. Anti-spoofing for "we met in person" is best-effort by nature and
/// must never be presented to users as a guarantee.
public enum Plausibility {
    /// Fastest movement treated as human. Generous on purpose: this must not flag someone
    /// catching a friend on a train.
    public static let maxSpeedKmH: Double = 900   // a plane

    public static func isPlausible(
        metresMoved: Double,
        secondsElapsed: Double
    ) -> Bool {
        guard secondsElapsed > 0 else { return false }
        let kmh = (metresMoved / secondsElapsed) * 3.6
        return kmh <= maxSpeedKmH
    }
}
