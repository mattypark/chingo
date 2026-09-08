# Next: the daily streak, the app icon, and caring for the bear

Written rather than built, because the session that scoped it ran low on room. Everything
here is decided — what is missing is the code.

## The decision that reverses a written one

`ios/ChinGoDesign/Sources/ChinGoEngine/Progress.swift:53-60` currently contains an argued
product stance **against** daily streaks. It cites Snapchat, calls a daily streak "a leash",
and the app's whole streak is deliberately measured in **weeks containing a real meetup**, not
days. `MapScreen.swift:530` hides it at zero with the comment "a streak that can shame you is
precisely the mechanic this app declined to copy."

Matthew has asked for consecutive days. That is his call and it is not a mistake — but the
comment must be **rewritten to say so**, not deleted. A future reader finding day-counting code
under an anti-daily-streak comment will assume one of them is a bug.

## Finch is the model for making it not a leash

Researched and confirmed from Finch's help centre and wiki:

- **Two Streak Repair Hammers.** Finite, so they are a real decision rather than an undo.
- **Repair with currency.** A second, costlier route.
- **Pause Mode.** Opt-in, set *before* you go away. Duolingo's freeze is the same idea; Finch's
  is manual, which is gentler because it is a plan rather than a purchase you forgot to make.
- **No scolding on return.** Multiple independent reviews confirm a lapsed user is welcomed
  back, not told off. This is the part that matters most and the part that costs nothing.

Finch also has no per-habit streak at all, no punishment for a missed goal, and a pet that
cannot die or regress. Its widget shows the bird having its own adventures while you are away
— autonomous rather than waiting for you. That is the tone to copy.

## The architectural decision this forces

`ios/ChinGo/Sources/Model/MapState.swift:43-45` states plainly that XP and the streak are
**derived from what actually happened, never stored**. `recompute(from:)` rebuilds both from
the `CatchRecord` list on every change.

Freezes, claimed rewards, a chosen app icon and a last-active day **cannot be derived**. They
are state. So this invariant has to break, deliberately, and the comment updated. The
established migration pattern is right there in `Store.swift:168-170`: add a non-optional
property with a default so existing installs pick it up without a schema version.

## A latent bug to fix while in there

`MapState.award()` (`:39-41`) increments `xp`, and the next `recompute` (`:49-51`) discards it.
`MapScreen.swift:469` calls `award(.caught)` in an `.onDisappear`, so it is double-counted and
then thrown away. Nobody has noticed because the number is recomputed correctly from catches.

## Where the engine goes

`Streak.current(weeksWithMeetup:currentWeek:)` in `Progress.swift:63` is a good shape to mirror:
pure, no `Date`, no `Calendar`, trivially testable. A day-based sibling belongs beside it in
`ChinGoEngine`, tested in `Tests/ChinGoEngineTests/` — **not** `ChinGoDesignTests`, which is
where a previous plan wrongly put it.

Keep `Date` → day-ordinal conversion up in `MapState`, as the week version already does.

## The app icon

Matthew asked for **both**: milestones unlock icons you pick, *and* it changes on its own when
you have been away.

**The constraint that shapes this:** `setAlternateIconName` always shows a system alert — "You
have changed the icon for ChinGo" — and there is no public way to suppress it. Duolingo's guilt
icons do trigger it. Private workarounds exist and risk rejection.

So the honest reconciliation:

- **Unlocked icons** are chosen in the profile. The alert makes sense there: you asked.
- **The lapse icon is opt-in**, a toggle defaulting off, worded as something the bear does
  rather than something done to you. Auto-swapping without asking fires a system alert at
  somebody who is in another app entirely.

Mechanics: check time-since-last-activity on launch (Duolingo does exactly this — it cannot be
done from a push; the app must be running). Reset the moment they come back.

Wiring: `project.yml:34-107` declares Info.plist keys under `info.properties`, and nested dicts
are already used. Add `CFBundleIcons` with `CFBundlePrimaryIcon` and `CFBundleAlternateIcons`.
Alternate icon files must be loose PNGs at the bundle root, not asset-catalog members — unless
you use `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` plus `INCLUDE_ALL_APPICON_ASSETS`. There
is precedent for the loose-file route: `UIAppFonts` at `project.yml:63-65` uses bare filenames
because the build flattens `Resources/Fonts` to the bundle root.

## Caring for the bear

Finch's loop, for reference: real self-care tasks fill an energy bar; at full energy the bird
leaves on a ~6-hour journey and comes back with a discovery. Currency buys outfits and 235 dyes
across 7 independently-coloured body zones — which implies a layered rig rather than baked
sprites, though no engineering source confirms the technique.

ChinGo's equivalent of "a task" is already obvious and already the point: **meeting somebody**.
Resist inventing chores. The bear should be fed by the thing the app is for.

## Animation stack — correcting an assumption

Finch is **not confirmed** to use Rive. Their Senior Animator listing requires advanced After
Effects and lists Rive only as *preferred*, which points at an AE → Lottie pipeline. One agency
pitch mentions Rive but it is their own capability claim, not a Finch statement.

For ChinGo the earlier recommendation stands: Rive is the right tool for an interactive hug,
because a video clip cannot respond to a finger — but `.riv` files are authored in a GUI that
cannot be driven from here. `fal-ai` is already connected if frame sequences are preferred, and
frame sequences are what Bump actually ships for animated profile pictures (H.265, 2.5s,
256×320 with an alpha plane, ~64KB).
