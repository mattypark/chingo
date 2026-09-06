# ChinGo

**Collect the people you meet. Never lose the ones you had.**

친구 (*chingu*) — friend.

ChinGo is a map of people. You walk around the real world; when you're standing next to
someone, you catch each other, and they become a card in your album. How close you actually
are decides how rare their card is — and closeness is earned by seeing each other, never
bought.

The other half matters more. Your camera roll is already full of geotagged photos with
people you've drifted from. ChinGo pins those to the places they happened, and when you walk
past one, it hands the memory back to you with a single button on it: **reconnect**.

Every incumbent in this category is built on *live* location — where everyone is, right now.
That is what got Zenly shut down, Life360 sued, and Instagram Map a letter from 37 state
attorneys general. ChinGo never shows where anyone is right now. It shows where you have
already been, together.

Free for everyone. Always.

## How catching works

Two paths, and both need the other person to tap accept. Nobody is ever collected.

| | **SNAP** — in person | **TAG** — light |
|---|---|---|
| Both phones confirm you're actually together | ✓ | — |
| Produces a shared photo | ✓ | — |
| Drops a memory pin where it happened | ✓ | — |
| Counts toward your bond tier | fully | barely |

SNAP is the engine: the photo it takes *is* the memory that finds you again in two years.

## Bond tiers

Earned, symmetric, and untouchable by money. You cannot be someone's Ride-or-die unless
they are yours.

| Tier | How |
|---|---|
| Met | one catch |
| Regular | 3+ meetups across 2+ places |
| Crew | 10+ meetups, 5+ places, 3 months |
| Ride-or-die | 25+ meetups, a year, each other's top five |

## Layout

```
ios/          SwiftUI app — map, catch, album, memories
  ChinGoDesign/   design system (colour, type, motion) + ChinGoEngine (pure rules)
web/          Next.js 16 — landing, public card pages
worker/       Cloudflare Worker — map tiles, image delivery, avatar jobs
supabase/     Postgres + PostGIS schema, RLS policies, RLS tests
docs/         DESIGN, PRIVACY, IP-BOUNDARY, STAGES
```

## Running it

```bash
cd ios && xcodegen generate           # regenerate the Xcode project
xcodebuild -project ChinGo.xcodeproj -scheme ChinGo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

cd ios/ChinGoDesign && swift test     # the rules, no simulator needed
```

No secrets required. Without `Secrets.xcconfig` the app runs on seeded local data, which is
a working state rather than a broken one.

## Working on this

Two sessions run in parallel, each in its own lane. Prompts to paste are in
[`nextsessions/`](nextsessions/); the rules behind them are in
[`docs/SESSION-FRONTEND.md`](docs/SESSION-FRONTEND.md) and
[`docs/SESSION-BACKEND.md`](docs/SESSION-BACKEND.md).

- **Frontend** — screens, components, design system, mascot
- **Backend** — rules engine, database, worker, release, App Store Connect

A screen that needs a rule which does not exist asks the backend session for it rather than
computing it in a view. Rules live in `ChinGoEngine`, which is pure and testable without a
simulator, so they can be proved rather than eyeballed.

Getting it onto other people's phones: [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md).

## Status

Early. The map, the design system and the rules engine are real; the basemap is a
placeholder until MapLibre lands, and nothing talks to a server yet.
