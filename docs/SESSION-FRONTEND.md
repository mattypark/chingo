# Frontend session

Owns everything a person looks at.

## What this session owns

| Area | Path |
|---|---|
| Screens and flows | `ios/ChinGo/Sources/Features/` |
| Components | `ios/ChinGo/Sources/Components/` |
| Design system — colour, type, motion, haptics, sticker language | `ios/ChinGoDesign/Sources/ChinGoDesign/` |
| App shell, splash, onboarding | `ios/ChinGo/Sources/Root/`, `Features/Onboarding/` |
| The mascot and image assets | `assets/logo/`, `Resources/Assets.xcassets/` |
| The design contract | `docs/DESIGN.md` |

**Does not touch** `ChinGoEngine`, `supabase/`, `worker/`, or `scripts/`. If a screen needs a
rule that does not exist — a new tier threshold, a different XP curve — ask the backend
session for it rather than computing it in a view. Rules live in one place so they can be
tested without a simulator.

## The standing rules

Full detail in `docs/DESIGN.md`; this is what gets broken most often.

- **`docs/DESIGN.md` is a contract, not documentation.** Re-read it before changing a view.
  Raw hex, arbitrary spacing and one-off corner radii are not allowed — `Ink`, `Space`,
  `Radius`, `Elevation`, `Motion` and `Feedback` are closed sets with no initialisers precisely
  so a view cannot invent a value.
- **The sticker language.** Hard shadows with zero blur, 3pt outlines, flat fills, press sinks
  the block into its own shadow. Derived from Bagel Fat One: no thin stroke anywhere. It is
  also what keeps this from looking like Pokémon GO, whose chrome is glassy — translucent
  fills, hairline strokes, soft blur. Those three are banned.
- **Bagel for numbers and short shouts. Never a sentence.** SF Pro carries anything read.
  Gloria Hallelujah is a person speaking, never a control label.
- **Three juice moments only** — catch, level-up, memory resurface. Everything else is quiet.
- **Contingent responsiveness.** Every tap gets a visible response inside 100ms, even when the
  real work takes longer. Under that line a reaction feels caused by you; past it the interface
  feels inert, and a mascot that looks like it has agency but does not react is judged worse
  than a plain graphic.
- **No whimsy in permission, error or safety states.** The bear is present, not performing.
  Cuteness in a broken flow reads as evasive.
- **No guilt mechanics.** Coming back is greeted, never scolded.
- **Every screen needs four states** — content, empty, loading, error. An empty rail with
  nothing in it is the moment an app is most obviously a database with no rows.

## Verifying

```bash
./scripts/dev.sh        # regenerate the Xcode project after adding files
cd ios && xcodebuild -project ChinGo.xcodeproj -scheme ChinGo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
cd ios/ChinGoDesign && swift test
```

Screenshot what you change. `-seedDemo` fills the store with realistic data;
`-open <album|profile|catch|deck>` lands on a surface directly; `-resetOnboarding` walks first
run again. Without those, a screen ships on trust — which is how one goes out with its own
close button clipped off the bottom.

Simulator note: it wedges a stale permission alert over the first screen surprisingly often.
`xcrun simctl erase <device>` clears it. That is the simulator, not the app.

## The prompt for this session

```text
You are the frontend session for ChinGo, at
~/Downloads/current-projects/appscurrent/chingo.

Read docs/SESSION-FRONTEND.md and docs/DESIGN.md first, and treat DESIGN.md as a
contract rather than documentation — it exists because AI-built UI drifts back
toward generic defaults over a long session.

You own: Features/, Components/, Root/, ChinGoDesign, the mascot and the asset
catalogue. You do not edit ChinGoEngine, supabase/, worker/ or scripts/ — the
backend session owns those. If a screen needs a rule that does not exist, ask for
it rather than computing it in a view.

The visual language is "sticker book", derived from Bagel Fat One: hard shadows
with zero blur, 3pt outlines, flat fills, and a press that sinks the block into
its own shadow. No thin strokes, no translucent fills, no soft blur — those three
are what make an app look like Pokemon GO, and this one deliberately does not.

Build and screenshot everything you change; do not describe a screen you have not
looked at. Commit after every change. Never push unless asked.

Current state: map, catch, album, memories, profile, splash and onboarding all
work. 43 tests pass.

Start by building the app, screenshotting the map and the profile, and telling me
the three weakest things you see.
```
