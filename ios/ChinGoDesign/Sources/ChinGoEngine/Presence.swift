import Foundation

/// The rule that decides whether another human being is allowed to appear on your screen.
///
/// This is the most safety-critical file in the app. Zenly is dead. Life360's location-data
/// class action (E.S. v. Life360, N.D. Cal. 4:23-cv-00168) was voluntarily dismissed with
/// prejudice in November 2023, but the Tile-tracker stalking suit against Tile, Life360 and
/// Amazon was still alive in the same court in August 2025 after a partial dismissal. Instagram
/// Map drew a letter from 37 state attorneys general demanding minors be blocked from location
/// sharing. The difference between this app and those is enforced here and in the RLS policies
/// — not in the UI.
///
/// Three rules, in order:
///   1. Precise position is live-only. It is shown inside the public server, while you are
///      discoverable, to others who are also discoverable, within the radar radius — and it
///      is never written down. Everything that is stored, and everything on the friends
///      server and in the album, resolves to a cell centroid. `GeoCell` quantises at the edge
///      so the database never holds a point it could leak later.
///   2. A cell reveals nothing until at least `k` people occupy it.
///   3. Discovery is opt-in per session, so being findable is something you switch on
///      when you go out, not a property of owning the app. And it is reciprocal: if you are
///      not findable, you do not get to find.
///
/// Rule 1 used to say a precise position is never exposed at all. Drawing people as avatars
/// standing where they stand — chosen deliberately, with the cost explained — changed it. The
/// line it draws now is live versus recorded: what got the apps above into trouble was history
/// and inference — a stored trail, a data broker, a tracker in a car — not the sight of someone
/// across the street. An avatar is a transient render that is gone the moment either of you
/// moves away or switches off. Nothing about it is stored, so there is nothing to leak later.
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
        /// other properly. Outside the public server's live view, this is the only path to
        /// a precise position.
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

    // MARK: - Live positions on the public server

    /// Where somebody starts being drawn. Matches `Geo.memoryRadiusMetres`: the app has
    /// carried 150 m as its idea of "nearby" since before there was a map, and one number
    /// for both keeps "who I can see" and "what surfaces for me" the same distance.
    public static let discoveryRadiusMetres: Double = Geo.memoryRadiusMetres

    /// Close enough to walk over and say something. Pokémon GO settled on 80 m for the same
    /// job after trying 40 and reverting under enough pressure that they made 80 permanent.
    public static let interactionRadiusMetres: Double = 80

    /// Where somebody already drawn stops being drawn.
    ///
    /// A third further out than the radius that let them in. Phone GPS in a city drifts five
    /// to twenty metres and does not hold still, so without a gap anyone near the boundary
    /// strobes on and off the map several times a minute. Pikmin Bloom uses 90 m in and
    /// 120 m out for exactly this.
    public static let releaseRadiusMetres: Double = 200

    public enum LiveVisibility: Sendable, Equatable {
        /// Draw nothing — not a greyed marker, not a "hidden" badge.
        case suppressed
        /// Draw them where they actually stand.
        case precise
    }

    /// Everything the live rule needs to know about one other person, right now.
    public struct LiveQuery: Sendable {
        public let viewerIsDiscoverable: Bool
        public let subjectIsDiscoverable: Bool
        /// True distance between the two phones. Live only; never stored.
        public let metresApart: Double
        /// Discoverable people currently in the subject's cell — what `cell_occupancy`
        /// returns. Rule 2 applies to a person exactly as it applies to a crowd bubble.
        public let cellOccupants: Int
        public let hasMutualHandshake: Bool
        /// Whether this person was drawn last time. Drives the hysteresis between the
        /// discovery and release radii.
        public let wasVisible: Bool

        public init(
            viewerIsDiscoverable: Bool,
            subjectIsDiscoverable: Bool,
            metresApart: Double,
            cellOccupants: Int,
            hasMutualHandshake: Bool = false,
            wasVisible: Bool = false
        ) {
            self.viewerIsDiscoverable = viewerIsDiscoverable
            self.subjectIsDiscoverable = subjectIsDiscoverable
            self.metresApart = metresApart
            self.cellOccupants = cellOccupants
            self.hasMutualHandshake = hasMutualHandshake
            self.wasVisible = wasVisible
        }
    }

    /// Whether one other person may be drawn where they actually stand.
    ///
    /// This is rule 1's only exception, and every condition is a gate rather than a
    /// preference: both people findable, the cell full enough, and inside the ring. Take any
    /// one away and the answer is nothing — which is also what the friends server, the album
    /// and the database get, always, because none of them call this.
    public static func livePosition(for q: LiveQuery) -> LiveVisibility {
        // A distance that is not a distance draws nothing. NaN compares false against
        // everything, so without this it would sail through the radius check below.
        guard q.metresApart.isFinite, q.metresApart >= 0 else { return .suppressed }
        // Same standing as in the cell rule: an explicit, two-sided, in-the-moment agreement
        // outranks every other gate.
        if q.hasMutualHandshake { return .precise }
        // Reciprocal in both directions. A hidden viewer sees nobody; a hidden person is
        // seen by nobody. One-way is the surveillance seat.
        guard q.viewerIsDiscoverable, q.subjectIsDiscoverable else { return .suppressed }
        // Rule 2 survives the change. The argument was never about the marker: a lone
        // person on an empty street at night should not be findable by a stranger walking
        // towards them, and k people in the cell is what "not alone" means.
        guard q.cellOccupants >= kAnonymityFloor else { return .suppressed }
        let limit = q.wasVisible ? releaseRadiusMetres : discoveryRadiusMetres
        return q.metresApart <= limit ? .precise : .suppressed
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
