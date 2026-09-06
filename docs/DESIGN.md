# ChinGo design contract

Read this before changing any view. It is a contract, not documentation — the values below
are the only ones allowed in view code.

The reason it exists in this form: AI-assisted work degrades over long sessions unless the
spec is re-read each time, and the failure mode is always the same. Every generated interface
converges on one spacing value, one corner radius, one shadow, one fade. The result reads as
machine-made because nothing in it was decided. These tokens are enums with no initialiser
precisely so a view *cannot* invent a number.

## The banned list

Each of these is a named tell. None of them ship.

- **Purple→blue or indigo gradients.** Called "the Times New Roman of AI-generated design."
- **Decorative glow, aurora, or bloom** behind content.
- **Emoji as icons or bullets.** SF Symbols, always.
- **Cards nested more than two deep.**
- **One corner radius on everything.** Radius tracks size — see `Radius`.
- **One spacing value on everything.** Spacing carries meaning — see `Space`.
- **Meaningless status dots and one-sided coloured borders.** Decoration that looks like data
  is worse than no decoration.
- **A single fade-in reused everywhere.** Motion has direction — see `Motion`.
- **Unmodified defaults and reflexive glassmorphism.**
- **`Item 1` / `User Name` placeholder data.** Previews and seeds use realistic content;
  `DemoSeed.swift` is the reference.
- **Raw hex in a view.** Colour comes from `Ink`, always.

## Tokens

| Concern | File | Rule |
|---|---|---|
| Colour | `Palette.swift` → `Ink` | Never a literal. The map's colours live here too, so the basemap and the chrome above it stay one product. |
| The accent | `Accent.swift` → `@Environment(\.accent)` | The one colour the app does not choose. Eight measured hues, picked in onboarding, stored as an index on `MeRecord.bannerTint`. Read from the environment, never from `Ink` — a `static let` cannot change and cannot tell SwiftUI that it did. |
| Sky | `Sky.swift` | Solar altitude from a coordinate, offline. A palette keyed on the angle, never on the clock. |
| Type | `Typography.swift` | Bagel Fat One for numbers and two-word shouts, never a sentence. SF Pro for anything read. Gloria only when a person is speaking. |
| Spacing | `Tokens.swift` → `Space` | 8pt grid, 4pt subdivisions. `hair` 4 · `tight` 8 · `snug` 12 · `step` 16 · `inset` 20 · `margin` 24 · `section` 32 |
| Radius | `Tokens.swift` → `Radius` | Three tiers: `control` 12 · `card` 20 · `surface` 28 |
| Elevation | `Sticker.swift` → `Sticker.drop` | Hard, zero blur, one offset. `Tokens.swift` → `Elevation` still holds the four soft recipes, but nothing on the map screen uses them any more — see below. |
| Motion | `Motion.swift` | Interface springs, three reward beats, two ambient loops |
| Haptics | `Haptics.swift` → `Feedback` | Five events, closed set |

### What building it overruled

Two rules in the original contract lost to looking at the running app. Both are recorded here
rather than quietly edited out, because the reasoning is the useful part.

**Everything on the map is a sticker now, not a floating surface.** `Surfaces.swift` argued
that nothing should ever be docked to an edge in a bar — that Pokemon GO's screen works
because each control is a small, detached object above the map. That is true of Pokemon GO
and it was not true here: the map's chrome was the last place still using soft blurred
elevation while every sheet and card had moved to `Sticker`, and two languages on one screen
reads worse than either does alone. The top pills, the catch button, the player puck and the
memory polaroids all take the 3pt outline and the hard drop now.

**The three corner controls became one bar.** Three controls pinned to three corners with the
width of the screen between them did not read as a set. `HomeBar` docks them, and the catch
button breaks its top edge so it keeps the size its hold gauge needs. The screen got calmer,
not heavier.

The one thing allowed a soft edge is `SkyBand`, and only because it is not printed on the
world — it is the world. A sky with a hard bottom edge is a coloured rectangle stuck to the
screen.

### Spacing carries meaning

`tight` between a value and its caption. `section` between unrelated blocks. If everything on
a screen sits at `step`, the screen has no structure — it has a gap size.

### Radius tracks size

A 40pt chip and a 400pt sheet cannot share a radius. At one value, one reads as square and the
other as a pill.

### Elevation is not one shadow

A pill resting above the map, a card, and a sheet covering half the screen are at different
heights. Cards get a second tight contact shadow via `.elevated(.low)` — the first shadow gives
height, the contact shadow stops it looking pasted on.

### Motion has direction

Ease-out springs for things arriving (`Motion.arrive`), ease-in for things leaving
(`Motion.dismiss`). Exits are always faster than entrances; an exit that lingers reads as a bug.

Three moments get the whole reward budget — **catch, level-up, memory resurface** — through
`RewardPhase` (anticipate → impact → settle). Nothing else animates like a reward. Pokémon GO's
own players revolted when every XP gain became a blocking full-screen modal; celebration scales
to what actually happened.

### Haptics are a vocabulary

`.pick` on a pin or card · `.caught` on a catch · `.arrive` on something landing · `.refused`
on a boundary · `.levelled` on a level. **Never on scroll.** A phone that buzzes constantly
teaches people to ignore it, which costs the two moments that matter.

## Required per screen

Before a screen is done it has all four:

1. **Content** — the happy path.
2. **Empty** — written in Gloria, as a person talking, not "No data available."
3. **Loading** — `.redacted(reason: .placeholder)` skeletons shaped like the content.
   Never a bare spinner.
4. **Error** — what happened and what to do, human-readable. Detail goes to logs.

## Accessibility, which is craft not compliance

- Every tappable thing clears 44×44pt. Use `.hitTarget()` — expanding a frame grows the layout
  but not the tap region, which is the quiet version of this bug.
- System text styles only, so Dynamic Type works without extra effort. Verify at the largest
  accessibility size; text may wrap, it may not truncate.
- Every animation checks `Motion.reduceMotion`. A game is exactly the kind of app that forgets.
- Contrast at WCAG AA against the *actual* background, including over the map.

## Continuity

`matchedGeometryEffect` between a map pin and its memory sheet, and between an album card and
the full card. This single technique is most of what separates an app from a set of screens.
Counters use `.contentTransition(.numericText())` so numbers roll rather than snap.
