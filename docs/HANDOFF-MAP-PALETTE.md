# The basemap needs to be a game style, not a corrected navigation style

For the backend session. `scripts/` and the generated `chingo-style.json` are yours; this is
what the frontend now needs out of them, and what it is doing in the meantime.

The earlier version of this document asked you to fix a palette that had drifted. That ask is
still live and is at the bottom. It is no longer the main one. The map has since been rebuilt
against Pokémon GO's actual look, and the gap between what `build-style.py` emits and what the
app draws is now large enough that "correct the colours" undersells it by a lot.

## Where the numbers come from

Not taste. Two independent sources, and they agree:

- **Datamined shipped assets.** Pokémon GO's map surfaces are a tiling texture plus a small 1D
  ramp indexed by distance — `GroundRamp.png` (256×4), `ParkRamp.png`, `RoadRamp.png`,
  `RoadOutlineRamp.png`, `WaterGrad.png`, `SkyDay.png`. These are the *authored* values.
- **Pixel sampling of official full-resolution screenshots.** These are the *on-screen* values,
  after the palette tint and the engine fog. Match these.

Anything below marked "derived" is an interpolation and is labelled as such.

## The palette

Already live in `Palette.swift` under `// MARK: Map`. Reproduced here so `build-style.py` can
be made to emit it directly.

| token | value | what it paints |
|---|---|---|
| `mapLand` | `#A4EFAC` | `background` — the ground, everything that is not water, park or road |
| `mapLandParcel` | `#9CEEA9` | `landuse-*`, `aeroway-area`, `road_area_pier`, `highway-area` |
| `mapPark` | `#3FA878` | `landcover-*`, `landuse-cemetery` |
| `mapParkDeep` | `#2E9668` | the `park` layer — nature reserves and protected land |
| `mapWater` | `#25A0DB` | `water`, `waterway` |
| `mapRoad` | `#4E8E81` | every carriageway, every class |
| `mapRoadCasing` | `#F6F49F` | every casing, every class |
| `mapPath` | `#EAF4F4` | footways |
| `mapHaze` | `#D0F9FF` | not a style colour — see "The haze" below |

Three of these are counter-intuitive and are the ones most likely to get "corrected" back:

1. **The road is not neutral grey.** `#4E8E81` is a desaturated teal in the ground's own hue
   family — 35 lightness points darker and 40 saturation points down. A true grey road on a
   green field reads as pasted on. This relationship is asserted in `MapPaletteTests`.
2. **The casing is yellow and everything gets it,** down to parking aisles. It is the loudest
   colour on the ground. Hierarchy is carried by width alone; no class has its own hue.
3. **Parks are a 40-point lightness step below the ground, not a nudge.** On a field that is
   already green, a park five percent darker reads as a rendering artefact.

## The transforms the frontend is applying at runtime

All in `ios/ChinGo/Sources/Components/MapStyle.swift`, applied to the style JSON before
MapLibre sees it. Each one is here because the generated style cannot express it yet. Every
one of them would be better emitted at build time.

| transform | what it does | why |
|---|---|---|
| `repaint` | swaps every colour in the table above | generator still emits the warm-paper palette |
| `removeBuildings` | deletes `chingo-building-3d`, `building`, `building-top` | see below |
| `widenStreets` | scales road `line-width` by **2.6**, footways by **0.9** | see below |
| `ribbonCasings` | rewrites each `*-casing` width as its own road's width × **1.38** | see below |
| `roundStreets` | forces `line-cap` and `line-join` to `round` on every street layer | butt caps leave square ends in the grass at these widths; must be a *constant*, MapLibre Native iOS silently ignores `line-cap` expressions |
| `solidPaths` | strips `line-dasharray`, recolours to `mapPath`, deletes `bridge-path-casing` | see below |
| `deepenParks` | repaints the `park` layer to `mapParkDeep` | generator paints a national park and a lawn the same colour |

### No buildings

Classic Pokémon GO draws none. Stand inside one and you see the street, because the street is
what you are playing on. That is not simplification, it is figure/ground management: with
nothing else vertical, the gameplay markers own the Z axis completely.

Note for the record, since it will come up: buildings were *added* to Pokémon GO in the April
2024 "Rediscover GO" update, along with hills and biomes. We are deliberately targeting the
classic map, not the current one.

Removing them costs the densest source of texture in an urban basemap, and it has to be paid
back on three axes or the map reads as empty — which is what the next three rows are.

### Streets at 2.6×

In the reference a primary street is about 8% of the screen's width. This basemap gives it 3%,
because it descends from a navigation style where a road is a line telling you a route exists.
With the buildings gone the road network is the only structure left on the ground and has to
carry the whole map alone.

### Casings derived, not authored

Measured: a 98px carriageway carries a 17–20px casing on each side, so the outer edge is about
**1.38×** the fill — roughly a fifth of the road's width in yellow per side, at every zoom and
for every class.

The generated style instead gives each class its own hand-tuned casing (15 against an 11.5
road here, 22 against 18 there), so the ribbon changes proportions from street to street. That
is correct for a navigation map, where a casing separates two roads that touch. It is wrong
here, where it is the edge of a physical object, and objects do not change proportion when you
look at more of them.

If `build-style.py` emits casings, please emit them as the road's own width expression times a
single constant.

### Paths

`line-dasharray: [1.5, 0.75]` on `highway-path` / `tunnel-path` / `bridge-path` is why downtown
looks stitched: San Francisco has its pavements mapped, so every street comes with two dashed
lines beside it. Footways in the reference are solid pale ribbons with **no casing**, and they
do not scale with the roads — at road widths they read as a second, paler street network.

### Land parcels are texture

`landuse-*` is deliberately a *different* green from the background, but only just: a few
lightness points and under eight degrees of hue. That parcel-level variation is what replaces
buildings as low-frequency texture. Too much and the blocks read as a classification; none at
all and the ground reads as felt. Both bounds are asserted in `MapPaletteTests`.

## The haze — and why it is not in the style

The reference's ground is not one colour: it runs `#A4EFAC` underfoot to `#6BE8CC` at the
horizon. The mechanism is Unity linear fog — every surface blended toward one colour with
distance, and that colour is the sky's own bottom edge. It is why their roads get *lighter*
with distance while their ground gets *darker*: both converge. There is no horizon line in that
game because at the horizon everything is already the same colour.

**MapLibre Native has neither fog nor sky.** Both are open upstream issues, not oversights:
`maplibre-native#4414` (no `sky`) and `#252` (no terrain); root `fog` is not in the MapLibre
style spec at all. A `{"type":"sky"}` layer copied from a Mapbox v3 style fails MapLibre
validation outright.

So it is a SwiftUI layer, `ios/ChinGo/Sources/Components/Haze.swift`. At a fixed camera pitch
screen Y is a monotonic function of depth, so a vertical gradient computes the same quantity in
a different parameterisation — this is not an approximation of fog, it is fog solved for y. The
alpha ramp is solved from nine road samples against the measured horizon colour and is sharply
non-linear; a linear ramp looks like a tinted window rather than air.

**Nothing is needed from the backend here**, with one exception: if the map's pitch ever
changes, the ramp is pitch-specific and has to be re-measured. Say so if it moves.

## Two things that would help, in order

1. **Have `build-style.py` read `Palette.swift` rather than mirroring it.** It is a flat list of
   `Color(hex: 0x……)` constants and is trivially parseable. Fail loudly on a token it cannot
   resolve. This is what stops the two files diverging again.
2. **Emit the geometry decisions above at build time** — widths, casing ratio, round caps,
   solid paths, no buildings. Every one of them is currently a JSON rewrite on app launch, held
   behind a cache keyed on `MapStyle.styleVersion` that has to be bumped by hand and has
   already cost one debugging session when it was not.

Once both land, `MapStyle` keeps only the accent wash. It is written so that deleting entries
from one dictionary and three functions is the whole change.

## The original drift, still true

`build-style.py:27` defines `"land_alt": "#E9E2CF"`, a key that exists nowhere in
`Palette.swift`, and lines 74–78 apply it through a branch whose two arms are identical:

```python
elif "landuse" in tag or "landcover" in tag:
    flat("fill-color", INK["land_alt"])
else:
    flat("fill-color", INK["land_alt"])
```

The `else` is a catch-all, so `land_alt` reaches ten layers while the real ground colour reaches
exactly one — the `background` underneath them all.

That bug is now doing useful work by accident: those ten layers are precisely the land parcels,
and `MapStyle` maps `#E9E2CF` to `mapLandParcel`. If you fix the branch, keep the distinction —
parcels genuinely want their own colour. What is wrong is that the colour was invented and
unnamed, not that there are two of them.

Also still true: `#f2eae2` and `#dfdbd7` survive unrepainted from OpenFreeMap's `bright` style
(lowercase is the tell — everything repainted is uppercase), and `road_minor` (`#F7F2E4`) is
defined and never read. Both are on building layers that are now deleted at runtime, so neither
is urgent.

---

# A night style

Second ask, same file. `SkyBand` dims the map as the real sun goes down, and it can only go so
far: the basemap is a daylight style. Street names sit on a light halo; darken the ground under
them and they are the first thing to go, so the dusk layer is capped at 34% and evening is as
far as it can honestly reach.

A real night needs the style to have a night variant — ground, water and, above all, label and
halo colours. That is `build-style.py`'s to emit. The frontend can switch between two style
files at runtime the same way it already switches between eight accent-tinted ones:
`MapStyle.url(for:)` is already keyed on something, and adding a second dimension to that key is
small once there is a second style to point at.

Worth knowing before you build it. Pokémon GO does **not** keep a separate night theme — it
drives the whole map tint from one sky state, with the sky and horizon colours authored as two
separate 4×4 lookup textures (`tx_day_sky_color.png`, `tx_day_horizon_color.png`) that the
palette service swaps. In every cell of those, **the horizon is lighter and less saturated than
the sky above it.** That single relationship is most of why their horizon reads as clean: it is
the *lowest*-contrast part of the frame, not the highest.

So if `build-style.py` emitted the label and halo colours as the only genuinely night-specific
values, the frontend wash could keep doing the rest.
