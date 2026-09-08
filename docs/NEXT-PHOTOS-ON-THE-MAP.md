# Next: photos pinned where they were taken

Matthew's framing, and it is the closest thing here to the app's actual purpose: *"you take a
picture when you're travelling and it pinpoints back to where it is, and if you're near it it
shows the exact location."*

## It is possible, and half the groundwork is already laid

`NSPhotoLibraryUsageDescription` already exists at `ios/project.yml:80-82`, and its copy already
describes this feature — it was written ahead of the implementation:

> "ChinGo finds photos you already took with friends and pins them to the places they happened.
> The photos stay on your phone."

`PHAsset.location` returns a `CLLocation` for any asset with GPS EXIF. That is the whole
mechanism.

## What does not exist yet

The Photos framework is **not used anywhere in the app**. Zero references to `PHPhotoLibrary`,
`PHAsset`, `import Photos` or `PhotosUI` across the tree.

`ios/ChinGo/Sources/Components/CameraPicker.swift` is a `UIImagePickerController` wrapper that
falls back to `.photoLibrary` only when there is no camera (so the catch flow is drivable in the
simulator). It reads `info[.originalImage]` and nothing else — no `PHAsset`, no metadata, no
location. `PhotoStore` is unrelated: app-owned JPEGs in Application Support.

## The permission trap

`PHAsset.location` needs **full** authorization. iOS defaults people toward "Select Photos…",
and under `.limited` you only see assets the user hand-picked, which makes a map of where you
have been meaningless.

App Review will compare the usage string against a `PHPhotoLibrary.requestAuthorization(for:
.readWrite)` prompt. The string is already honest about the purpose, which helps.

Design implication: `.limited` must not be treated as a failure. It is a legitimate answer and
the feature should degrade to "here are the ones you picked" rather than nagging.

## Where the row goes

`ios/ChinGo/Sources/Features/Onboarding/PermissionList.swift` already has the pattern: a
switch per permission, and flipping a switch fires the real prompt. A fourth row plus a
`@Binding` and an `onPhotos` closure, wired from `OnboardingFlow.swift`.

Worth deciding first: photos are a *large* ask sitting next to location and notifications, and
Bump's own permissions screen holds four rows before people start tapping to make it stop. It
may belong after onboarding, at the moment somebody first opens the album — where the payoff is
visible and the ask explains itself.

## Sketch of the work

1. `PhotoPlaces` service: request authorization, fetch assets with `location != nil`, map to
   coordinate + date + local identifier. Never copy the image — hold the identifier and load on
   demand.
2. Cluster by `GeoCell` (already exists, `GeoCell.swift`) so a hundred photos from one holiday
   are one pin.
3. Reuse `MemoryRecord`'s resurfacing rule (`Resurface.swift`) — "you are near a place something
   happened" is already built and tested.
4. Pins reuse the marker work already done on the globe.
