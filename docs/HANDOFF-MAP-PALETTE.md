# The basemap palette has drifted from `Ink`

For the backend session. Frontend has worked around this; the root cause is in a file
frontend does not own.

## What is wrong

`scripts/build-style.py` keeps its own copy of the palette in an `INK` dict, with a comment
saying the two files change together. They have not.

### The ground is the wrong colour

`build-style.py:27` defines a key that exists nowhere in `Palette.swift`:

```python
"land_alt": "#E9E2CF",
```

and lines 74–78 apply it through a branch whose two arms are identical:

```python
elif "landuse" in tag or "landcover" in tag:
    flat("fill-color", INK["land_alt"])
else:
    flat("fill-color", INK["land_alt"])
```

Because the `else` is a catch-all, `land_alt` reaches **ten** layers — `landuse-residential`,
`-suburb`, `-commercial`, `-industrial`, `-hospital`, `-school`, `-railway`, `aeroway-area`,
`road_area_pier`, `highway-area` — while the real `Ink.mapLand` `#EDE7D6` reaches exactly
**one**, the `background` layer underneath them all.

So at city zoom the ground you see is an invented colour that is darker than the palette
specifies, and darker again than the `Ink.ground` chrome sitting on top of it. This is the
"map's ground renders darker than the palette specifies" note in `nextsessions/FRONTEND-PROMPT.md`.

### Three building colours have drifted

| `INK` key | in `build-style.py` | `Ink` token | in `Palette.swift` |
|---|---|---|---|
| `building` | `#F2EBDA` | `mapBuilding` | `#E4DCC8` |
| `building_warm` | `#EADEC8` | `mapBuildingWarm` | `#DCCFB4` |
| `building_side` | `#DCCDB2` | `mapBuildingSide` | `#C6B99C` |

### Two upstream colours were never repainted

`#f2eae2` and `#dfdbd7` survive from OpenFreeMap's `bright` style on the `building` and
`building-top` layers. Lowercase, which is the tell — everything repainted is uppercase.

### One dead key

`road_minor` (`#F7F2E4`) is defined and never read.

## What frontend did about it

`ios/ChinGo/Sources/Components/MapStyle.swift` rewrites the style JSON on the way into
MapLibre: it maps each drifted colour back to its `Ink` token, then washes the neutral family
toward the player's chosen accent. Water and parks are deliberately untouched.

That was not a preference. A per-player accent cannot be baked into a static build artefact,
so the tint had to happen at runtime anyway, and correcting the palette in the same pass cost
nothing. It also stays inside the ownership line: `scripts/` is yours, and the generated
`chingo-style.json` carries a do-not-edit banner because the next regeneration would discard
any hand edit.

## What would actually fix it

Stop mirroring the palette by hand. `Palette.swift` is a flat list of `Color(hex: 0x……)`
constants and is trivially parseable; have `build-style.py` read it and build `INK` from what
it finds, failing loudly on a token it cannot resolve. Then fix the catch-all branch so that
non-landuse fills fall through to `land` rather than to a second ground colour.

Once the generated style is correct at the source, `MapStyle` should keep only the accent
wash and drop the `corrections` table. It is written so that deleting entries from that one
dictionary is the whole change.


---

# A night style

Second ask, same file. `SkyBand` now dims the map as the real sun goes down, and it can only
go so far: the basemap is a daylight style. Street names are `#6B655A` on a `#F6F2E7` halo,
chosen to sit on cream. Darken the ground under them and they are the first thing to go, so
the dusk layer is capped at 34% and evening is as far as it can honestly reach.

A real night needs the style to have a night variant -- ground, buildings and, above all,
label and halo colours inverted. That is `build-style.py`'s to emit. Frontend can switch
between two style files at runtime the same way it already switches between eight accent-tinted
ones: `MapStyle.url(for:)` is already keyed on something, and adding a second dimension to
that key is a small change here once there is a second style to point at.

Worth knowing before you build it: Pokemon GO drives its whole map tint from one sky state
rather than keeping a separate night theme, and its terrain desaturates to match the sky. If
`build-style.py` emitted the label and halo colours as the only night-specific values, the
frontend wash could keep doing the rest.
