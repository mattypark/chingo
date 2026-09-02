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
| Type | `Typography.swift` | Bagel Fat One for numbers and two-word shouts, never a sentence. SF Pro for anything read. Gloria only when a person is speaking. |
| Spacing | `Tokens.swift` → `Space` | 8pt grid, 4pt subdivisions. `hair` 4 · `tight` 8 · `snug` 12 · `step` 16 · `inset` 20 · `margin` 24 · `section` 32 |
| Radius | `Tokens.swift` → `Radius` | Three tiers: `control` 12 · `card` 20 · `surface` 28 |
| Elevation | `Tokens.swift` → `Elevation` | Four recipes: `low` · `float` · `card` · `sheet`. Applied with `.elevated(_:)` |
| Motion | `Motion.swift` | Interface springs, three reward beats, two ambient loops |
| Haptics | `Haptics.swift` → `Feedback` | Five events, closed set |

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
