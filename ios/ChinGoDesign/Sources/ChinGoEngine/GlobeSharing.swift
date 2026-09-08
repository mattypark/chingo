import Foundation

/// Who can see where you are on the globe, and — the harder half — what they are told when
/// they cannot.
///
/// The feature is a map of the whole planet with your friends on it. That is a category of
/// product with a bad history, so the rules are here, as functions, rather than spread across
/// a settings screen as booleans. Four of them:
///
/// 1. **Off by default, and off is a real off.** A new friend shares nothing in either
///    direction until somebody says otherwise. There is no "on for people you know well".
/// 2. **Per friend, not per account.** One switch for everybody means the decision is made
///    once, at the least informed moment, and then silently applied to every person you meet
///    afterwards.
/// 3. **Both sides, separately.** Showing somebody where you are and being shown where they
///    are are two different grants and neither implies the other. Bundling them is what makes
///    location sharing feel like a trade you have to accept to participate in.
/// 4. **Pausing is deniable.** This is the one that decides whether the feature is safe. If
///    stopping sharing produces "Matthew stopped sharing his location", then stopping is an
///    action with a social cost, and a feature you cannot leave without an argument is not
///    optional. So a paused friend and a friend whose phone is off produce the *same* result:
///    no recent position. Nothing anywhere may distinguish them.
///
/// Rule 4 is why `Visibility` has no `.paused` case. It is not an oversight and it is not a
/// simplification — a case that exists can be rendered, logged, or synced, and any of those
/// would leak the thing the rule is protecting.
public enum GlobeSharing {

    /// One friend's two grants, from your side of the relationship.
    public struct Grant: Equatable, Sendable {
        /// They may see where you are.
        public var iShare: Bool
        /// You may see where they are.
        public var theyShare: Bool

        public init(iShare: Bool = false, theyShare: Bool = false) {
            self.iShare = iShare
            self.theyShare = theyShare
        }

        public static let none = Grant()
    }

    /// What you can be told about one friend. Two cases on purpose; see rule 4.
    public enum Visibility: Equatable, Sendable {
        /// A position, and how old it is.
        case somewhere(latitude: Double, longitude: Double, age: TimeInterval)
        /// Nothing recent. Paused, offline, out of signal, battery dead, app closed —
        /// deliberately indistinguishable, and deliberately not carrying a reason.
        case quiet
    }

    /// How old a position may be and still be shown.
    ///
    /// Six hours. Long enough that a phone in a bag for the afternoon still shows a
    /// last-known city, short enough that nothing on the globe is ever meaningfully wrong
    /// about which country somebody is in. It also does the deniability work: a paused friend
    /// becomes `.quiet` on the same schedule as one whose phone died, rather than instantly,
    /// so the moment of pausing is not visible either.
    public static let freshness: TimeInterval = 60 * 60 * 6

    /// Whether you are allowed to see this friend at all.
    ///
    /// Requires the master switch, their grant, and — deliberately — your own. Somebody who
    /// has switched their own sharing off entirely does not get a one-way window onto their
    /// friends: this is a mutual feature or it is a tracking feature, and which one it is
    /// depends on exactly this line.
    public static func canSee(_ grant: Grant, globeEnabled: Bool, sharingPaused: Bool) -> Bool {
        globeEnabled && !sharingPaused && grant.theyShare && grant.iShare
    }

    /// Whether this friend is allowed to see you.
    public static func canBeSeenBy(_ grant: Grant, globeEnabled: Bool, sharingPaused: Bool) -> Bool {
        globeEnabled && !sharingPaused && grant.iShare
    }

    /// What to draw for one friend.
    ///
    /// Takes the position as an optional rather than asking whether one exists, because the
    /// call site should not be able to check for a position and then decide separately
    /// whether it is allowed to use it. There is one answer and this returns it.
    public static func visibility(
        of grant: Grant,
        globeEnabled: Bool,
        sharingPaused: Bool,
        latitude: Double?,
        longitude: Double?,
        updatedAt: Date?,
        now: Date = .now
    ) -> Visibility {
        guard canSee(grant, globeEnabled: globeEnabled, sharingPaused: sharingPaused),
              let latitude, let longitude, let updatedAt,
              now.timeIntervalSince(updatedAt) <= freshness
        else { return .quiet }

        return .somewhere(
            latitude: latitude,
            longitude: longitude,
            age: now.timeIntervalSince(updatedAt)
        )
    }
}
