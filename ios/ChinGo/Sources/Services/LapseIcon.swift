import UIKit
import ChinGoEngine

/// The icon the bear changes on its own, once you have been away a while.
///
/// **Checked on launch, because there is nowhere else to check it.** `setAlternateIconName`
/// only works with the app running, so this cannot be a push and cannot be a background task —
/// Duolingo's version of this works exactly the same way for exactly the same reason. It means
/// the swap happens the moment you come back rather than while you are away, which sounds
/// backwards and is the only honest version: the alert it fires belongs on a screen you are
/// looking at.
///
/// **Opt-in, and that is not a preference.** The system alert cannot be suppressed through any
/// public API, so an automatic swap on somebody who never asked fires "You have changed the
/// icon for ChinGo" at them in the middle of something else. Off unless `wantsLapseIcon`.
///
/// **It never scolds.** The lapse icon is the bear asleep, not the bear sad, and coming back
/// puts your own choice straight back. Nothing about this is allowed to keep score.
@MainActor
enum LapseIcon {

    /// How long away before the bear nods off. A week: shorter and a normal weekend away
    /// trips it, longer and it never fires for anybody it was meant for.
    static let quietDays = 7

    /// The icon used while you are away. Deliberately the sleeping bear rather than a sad one.
    static let sleeping = "AppIcon-Dozer"

    /// Reconcile the home-screen icon with how long it has been, and stamp today.
    ///
    /// Returns nothing and throws nothing on purpose: every branch here is allowed to do
    /// nothing, and a failure to set an icon is not worth interrupting a launch over.
    static func reconcile(
        lastActiveDay: Int,
        today: Int,
        chosen: String?,
        wantsLapseIcon: Bool
    ) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let target = wanted(
            lastActiveDay: lastActiveDay,
            today: today,
            chosen: chosen,
            wantsLapseIcon: wantsLapseIcon
        )
        guard target != UIApplication.shared.alternateIconName else { return }
        UIApplication.shared.setAlternateIconName(target)
    }

    /// Which icon should be on the home screen right now.
    ///
    /// Split out and pure so the rule can be reasoned about without a running app. The three
    /// cases it has to get right: opted out is always your own choice; a first launch is not a
    /// lapse; and coming back restores what you picked rather than leaving the bear asleep.
    static func wanted(
        lastActiveDay: Int,
        today: Int,
        chosen: String?,
        wantsLapseIcon: Bool
    ) -> String? {
        guard wantsLapseIcon else { return chosen }
        // Never opened before. A brand-new install has not lapsed, it has not started.
        guard lastActiveDay > 0 else { return chosen }
        return today - lastActiveDay >= quietDays ? sleeping : chosen
    }
}
