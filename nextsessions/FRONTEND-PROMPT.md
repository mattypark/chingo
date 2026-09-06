# Frontend session — prompt

Paste this into a fresh session.

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

## What it is walking into

- `./scripts/dev.sh` regenerates the Xcode project. Run it after adding files, and after any
  "Missing package product" complaint — then close and reopen the project.
- Launch flags: `-seedDemo` fills the store with realistic data,
  `-open <album|profile|catch|deck>` lands on a surface directly, `-resetOnboarding` walks
  first run again.
- Known rough edges: the map's ground renders darker than the palette specifies, and the map
  chrome is still in the old soft-shadow language rather than the sticker one.
- The simulator wedges stale permission alerts over the first screen. `xcrun simctl erase`
  clears it. That is the simulator, not the app.
