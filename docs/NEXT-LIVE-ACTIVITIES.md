# Next: Live Activities

Matthew asked for these and for it to be remembered as a direction rather than a one-off:
onboarding progress, location, feeding the bear.

## The blocker is project structure, not code

`ios/project.yml` declares **exactly one target**. There is no widget extension, no app
extension, no App Group. Zero references to `ActivityKit`, `WidgetKit` or
`NSSupportsLiveActivities` anywhere in the tree.

Live Activities cannot exist without a Widget Extension target, so the first commit here is a
project-structure change:

1. A `type: app-extension` target in `project.yml` with the WidgetKit info keys.
2. `NSSupportsLiveActivities: true` in the app's `info.properties`.
3. A shared `ActivityAttributes` type. `ChinGoEngine` is the natural home — it is pure logic,
   no UIKit, already a dependency of the app, and already compiles on macOS for tests.
4. An App Group entitlement if the widget needs to read app state. `entitlements:` at
   `project.yml:110-114` currently declares only Sign in with Apple.

## What is actually worth putting in one

Ranked by whether the information changes while you are not looking at the app, which is the
only thing a Live Activity is for:

- **Developing photos.** There is already a timer with a real deadline — `Develop.next(after:)`,
  the nine-in-the-morning rule. A Lock Screen countdown to a photo you already took is the
  clearest fit in the app, and it needs no new state.
- **Somebody nearby.** Genuinely live, genuinely time-limited. But `LocationService` is
  When-In-Use by design and refuses Always, so this cannot update while the app is closed
  without reversing that decision. Do not build it until the backend can push.
- **Onboarding progress.** Listed by Matthew, but onboarding happens with the app open and in
  your hand. A Live Activity for it would be showing you something you are already looking at.

## Note

`UIBackgroundModes` is not declared anywhere, and there is no `BGTaskScheduler`. Anything that
needs to update on its own needs either a push or a foreground visit.
