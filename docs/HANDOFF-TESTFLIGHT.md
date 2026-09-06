# What a Release build does that a Debug build does not

Found while putting **0.1.0 (3)** on TestFlight. None of it is a release blocker and none of
it is mine to fix — `Model/` and `Features/` are the frontend session's. Written down here so
the next person does not rediscover it from a tester's confused message.

Both of the first two are already covered in the TestFlight "What to Test" and in the notes
Apple's reviewer sees, so nobody should file them as bugs. They still want fixing.

## The app starts completely empty on a real install

`ios/ChinGo/Sources/Model/DemoSeed.swift:1` is `#if DEBUG`, and the call site
`ios/ChinGo/Sources/Root/ChinGoApp.swift:29-31` is inside the same guard. In the simulator you
get a populated album; a TestFlight install lands on nothing.

That may well be the right product decision — a collecting app that hands you a fake
collection is worse, not better. But an empty first screen has to *look* deliberate, and right
now it looks like a failed load.

## `canCatch` can never be true in Release

`ios/ChinGo/Sources/Model/MapState.swift:31-36`:

```swift
var canCatch: Bool {
    #if DEBUG
    return true
    #else
    return discoverable && !nearby.isEmpty
    #endif
}
```

`nearby` is initialised to `[]` at `MapState.swift:26` and **is never assigned anywhere in the
codebase**. So in Release `canCatch` is permanently false and the radial menu title is stuck on
"Nobody nearby yet" (`ios/ChinGo/Sources/Features/MapScreen.swift:163`).

The two menu actions are not disabled by it, so add-by-handle and the catch photo still work —
the app is usable, it just narrates its own failure at the top of the screen. Either write to
`nearby`, or make the empty state say something true.

## `Secrets.xcconfig.example` ships inside the app bundle

`ios/project.yml:26` sets `buildPhase: none` on it, and that is not taking effect —
`ios/ChinGo.xcodeproj/project.pbxproj:298` puts the file in the Resources copy phase, and it is
present in the shipped archive at
`build/testflight/ChinGo.xcarchive/Products/Applications/ChinGo.app/Secrets.xcconfig.example`.

**Nothing leaks.** The file is placeholders only. But the comment above it says it has no
business shipping inside the app bundle, and it is shipping inside the app bundle. Worth fixing
for build 4.

## The Supabase keys are wired to nothing

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `TILE_BASE_URL` are declared as Info.plist keys at
`ios/project.yml:93-95`, resolving `$(SUPABASE_URL)` and friends from build settings. Those
build settings are meant to come from `ios/ChinGo/Secrets.xcconfig` — but **`project.yml` has
no `configFiles:` entry**, so XcodeGen never wires the xcconfig as a base configuration. The
generated project has no `baseConfigurationReference` at all.

The keys therefore resolve to empty strings in every build, including the one on TestFlight.
It breaks nothing today: no Swift file reads them, there is no `supabase-swift` package, and
the app makes no network calls except MapLibre fetching public OpenFreeMap tiles. 0.1.0 is
local-first by design.

It matters the day something *does* need the backend, because the chain will look correct and
fail silently. Fix the `configFiles:` entry then, not before.

## Declared and unimplemented — leave alone

- `NSLocalNetworkUsageDescription`, `NSNearbyInteractionUsageDescription` and
  `NSMotionUsageDescription` (`ios/project.yml:68-84`) describe co-presence features with no
  implementing code — `Sources/Services/` holds only `LocationService.swift` and
  `PhotoStore.swift`. Harmless: the app never requests those permissions at runtime, so the
  strings are never shown. Apple's reviewer was told this explicitly.
- The Sign in with Apple entitlement (`ios/ChinGo/ChinGo.entitlements:5-8`) is declared and
  unused **on purpose** — `ios/project.yml:99-101` explains it exists to force an explicit App
  ID to register. **Do not remove it.** Removing it deregisters the App ID that the bundle ID
  and every future build depend on.
