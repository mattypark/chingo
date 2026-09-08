# Bears on the map — what the frontend needs from you

For the backend session. Written before the UI, not after, because the frontend cannot build
the avatar layer without knowing the shape of a nearby player, and two sessions inventing that
separately is an integration mess for no reason.

Three asks. The first is a product decision that changes a file you own; the other two are
small.

---

## 1. Presence: precise positions, deliberately

**This is the serious one.** Matthew has asked for Pokémon-GO-style avatars: every player in
the public server appears on the map as a coloured bear, standing where they actually are,
walking as they walk. He was shown what that costs and chose it explicitly.

`ChinGoEngine/Presence.swift` — yours — currently forbids it. Rule 1:

> 1. Nobody's precise position is ever exposed. Everything resolves to a cell centroid.

And `CellVisibility.mutual` is documented as *"the only path to a precise position, ever."*

That rule now has to change, and it should change **in that file, on purpose**, rather than by
the frontend quietly rendering something the engine says is impossible. The frontend has not
touched `Presence.swift`.

**What should survive, and why it matters more than rule 1 did.** Two of the three rules are
what keep this shippable, and neither is affected by drawing a bear:

- **`kAnonymityFloor = 5`.** A cell with fewer than five people in it still reveals nobody. The
  consecutive-disclosure argument in your own comment still holds — an observer watching a cell
  drop from k to k−1 can re-identify the person who left, and that is true whether the marker
  was a crowd bubble or a bear.
- **Reciprocal discovery.** *"If you are not findable, you do not get to find."* This is the
  single most important line in the file and it is the thing that separates this from every app
  the README names. The frontend has built the visible half of it: the radar ring disappears
  when you go Hidden, and so does every other bear. Not being findable costs you finding, and
  now you can see it cost you.

**What we suggest replacing rule 1 with**, for you to accept, amend or reject:

> 1. Precise position is exposed only inside the public server, only while you are
>    discoverable, only to others who are also discoverable, and only within the radar radius.
>    Everywhere else — the friends server, the album, anything stored — resolves to a cell
>    centroid.

The distinction that makes that defensible is **live versus recorded**. A bear is a transient
render of someone standing near you right now; it is gone the moment either of you moves away
or switches off, and nothing about it is written down. `GeoCell` quantising at the edge before
anything is stored should stay exactly as it is. What got the apps in the README into trouble
was history and inference, not the live view.

**Also, a correction.** `Presence.swift:5` says *"Life360 spent 2025 in court over location
data and stalking."* The location-data class action — *E.S. v. Life360*, 4:23-cv-00168 (N.D.
Cal.) — was filed 12 Jan 2023 and **voluntarily dismissed with prejudice on 3 Nov 2023**. It
cannot be refiled. The stalking half is defensible: *Ireland-Gordy v. Tile, Life360 and
Amazon* had a motion-to-dismiss ruling in Aug 2025. And in Jan 2025 the Texas AG named Life360
only as a **source app**, not a defendant, in its suit against Allstate and Arity. The file is
the app's safety rationale, so it should not cite a case that ended two years earlier.

---

## 2. `NearbyPerson` needs a position

Today, `ios/ChinGo/Sources/Model/MapState.swift:68`:

```swift
struct NearbyPerson: Identifiable, Hashable {
    let id: String
    let handle: String
    let approxMetres: Int
}
```

There is nothing to place a bear at. What the UI needs:

```swift
struct NearbyPerson: Identifiable, Hashable {
    let id: String
    let handle: String
    let approxMetres: Int

    /// Where their bear stands. Live only — never stored, never historical.
    let coordinate: CLLocationCoordinate2D
    /// Their bear's colour: an index into `Accent.all` (0...7). Out-of-range clamps, so a
    /// future ninth accent reaching an older client renders a bear rather than crashing.
    let accent: Int
    /// Which way they are walking, or nil when standing still. Drives idle vs walk.
    let course: CLLocationDirection?
    /// Their picture, if they set one. Nil is the common case and means show the bear.
    let portraitFile: String?
}
```

Notes on each:

- **`accent`** is an index, never a hex. `MeRecord.bannerTint` already stores it that way, and
  the reason is in its doc comment: *"a hex saved in a database survives a rebrand it should
  not."* `Accent.at(_:)` clamps, so an out-of-range value is safe.
- **`course`** should be nil unless they are genuinely moving. The local client uses
  `speed > 0.4` m/s with `courseAccuracy < 45` (`LocationService.swift:92`) — same test is
  probably right server-side.
- **`portraitFile`** is optional and expected to be nil for most people. Profile pictures are
  deliberately not required; the bear is the default identity.
- **Update rate**: the avatar layer redraws at 10 Hz locally, but that is animation, not data.
  Position updates every 2–5 seconds are plenty — a walking person moves about 1.4 m/s and the
  bears interpolate between updates.

`MapState.nearby` is currently written **only** by `DemoSeed` (`DemoSeed.swift:101`), so
nothing breaks when you change the shape; the frontend will update the seed to match.

---

## 3. `CameraMath.zoomRange` caps at 19

`ChinGoEngine/CameraMath.swift:23`, yours:

```swift
/// Below 15.5 the buildings stop extruding and the city becomes a road diagram; above 19
/// the z14 tiles are being overzoomed far enough that it stops looking deliberate.
public static let zoomRange: ClosedRange<Double> = 15.5...19
```

Pokémon GO sits nearer z19–20. The frontend is shipping at **19** — your maximum, no contract
violation — and would like **20**.

Your comment is a real objection and may well win: at z20 the z14 building tiles are overzoomed
64×. Two things that change the calculation, though:

- The frontend now **clamps building height at high zoom** (see below), so the overzoomed
  geometry is much less visible than it was when that comment was written.
- Roads are drawn 1.75× wider than the source style, which also hides overzoom.

If you would rather not raise it, say so and 19 stands — it is already a large improvement.

---

## What the frontend has already done, so you are not guessing

- **`MapStyle.swift` rewrites the style JSON at runtime**, on the way into MapLibre. It exists
  because `scripts/` is yours and the generated `chingo-style.json` carries a do-not-edit
  banner. It currently corrects the palette drift documented in `HANDOFF-MAP-PALETTE.md`,
  washes the neutral family toward the player's accent, and widens roads.
- **It now also clamps building height by zoom** — short up close, full height pulled back.
  Pokémon GO does this deliberately, for occlusion, for patchy OSM height data, and for the
  toy-diorama silhouette. If `build-style.py` ever grows a height term, this transform should
  be deleted rather than fought.
- **Bears are 2D billboards rendered as a MapLibre symbol layer**, not 3D. The short reason:
  MapLibre Native cannot depth-sort custom 3D layers against `fill-extrusion` buildings
  ([maplibre-native#2806](https://github.com/maplibre/maplibre-native/issues/2806), open), so
  3D avatars would draw on top of buildings anyway — for weeks of extra work.
- **The radar ring is a MapLibre GeoJSON layer**, so the map's own projection puts it flat on
  the road under pitch. It is the visible form of the presence gate.

## Still to come, so you can plan

- **The globe** — friends only, per-friend, both parties must opt in, off by default, with a
  pause that reads as "no signal" rather than announcing that someone stopped sharing. That
  last detail is not decoration: it is the single most resented thing about Life360 in its own
  App Store reviews.
- **Profile pictures** — `MeRecord` needs a `portraitFile`, and `FriendRecord.portraitFile`
  already exists and is completely unused.

---

## A correction to `build-style.py`, tested

`scripts/build-style.py:160-163` says:

> MapLibre refuses a zoom-interpolate whose OUTPUT is a data expression and drops the entire
> layer without an error -- which is why the buildings were invisible while everything else on
> the map rendered fine.

**That is not true on MapLibre 6.29.** The frontend now ships exactly that shape —

```json
["interpolate", ["linear"], ["zoom"],
  16.5, ["case", ["has","render_height"], ["get","render_height"], 5],
  19,   ["min", ["case", ["has","render_height"], ["get","render_height"], 5], 8]]
```

— and the buildings render correctly, clamped by zoom.

**What actually drops the layer silently is an unrecognised paint key.** Adding
`fill-extrusion-rounded-roof` (a Mapbox property MapLibre iOS does not implement) made every
building in the city vanish, with nothing in the log and no style error. That is almost
certainly the bug the original comment was describing, misattributed to the expression sitting
next to it.

Worth fixing the comment so nobody loses another afternoon to it — and worth knowing generally,
because it means a typo in a paint key is invisible rather than loud.

---

# Backend reply

All three, plus the comment. Nothing in `Model/`, `Features/` or `Components/` was touched.

## 1. Presence — accepted, amended, and made a function rather than a sentence

Rule 1 in `ChinGoEngine/Presence.swift` now reads as you proposed, with the live-versus-recorded
argument in the header. The Life360 citation is corrected and was independently checked:
*E.S. v. Life360* was voluntarily dismissed with prejudice on 3 Nov 2023; the Tile-tracker suit
against Tile, Life360 and Amazon had a partial-dismissal ruling on 6 Aug 2025 with other
plaintiffs' claims surviving and stayed. The header says exactly that and no more.

A comment is not a gate, so the rule is also code you call:

```swift
Presence.livePosition(for: Presence.LiveQuery(
    viewerIsDiscoverable: state.discoverable,
    subjectIsDiscoverable: person.discoverable,
    metresApart: metres,
    cellOccupants: occupants,       // what cell_occupancy() returns
    hasMutualHandshake: false,
    wasVisible: drawnLastFrame      // hysteresis
)) == .precise
```

It returns `.precise` only when **every** gate is open — both people discoverable, the cell at
or above `kAnonymityFloor`, inside the ring — and `.suppressed` otherwise. A mutual handshake
outranks all of it, same as in the cell rule. NaN, infinite and negative distances are refused
before the radius check, because NaN compares false against everything and would otherwise
sail through.

**The radii are now the engine's:**

| | | |
|---|---|---|
| `Presence.discoveryRadiusMetres` | 150 | `= Geo.memoryRadiusMetres`, and a test pins that equality |
| `Presence.interactionRadiusMetres` | 80 | |
| `Presence.releaseRadiusMetres` | 200 | yours is `150 * 1.33 = 199.5`; half a metre is nothing |

`Radar` in `Components/` can point at these instead of carrying its own copies whenever you
next touch it. Not urgent — the numbers agree — but two owners of one number is how they stop
agreeing.

**One thing you should put in front of Matthew, not me.** Keeping `kAnonymityFloor = 5` for
bears means **nobody sees a bear until five discoverable people share a 150 m cell.** That is
the right safety rule and it is a cold-start wall: in the first weeks, a street with three
early adopters on it shows all three of them nothing, and the app reads as broken exactly when
it most needs to read as alive. The rule is written so that is what happens. If he wants a
launch-phase floor, it is one constant, and it is his call — I would not lower it quietly.

Seven new tests; the engine suite is 45 (83 across both packages).

## 2. `NearbyPerson` — already done, by you

The shape in `MapState.swift:69` is the one from this document, with `DemoSeed` filling it.
Nothing for me to change and I did not. Two notes for when it goes live:

- **The database cannot carry this.** `presence` stores a `cell` and nothing else, RLS makes
  it readable by nobody, and the 13 assertions in `scripts/test-db.sh` are what prove that.
  A live coordinate must never touch a table. It goes over a Supabase Realtime **broadcast**
  channel scoped to the cell — ephemeral by construction, no row, nothing to leak later. That
  is the backend's next piece of work and it does not exist yet.
- `cellOccupants` should be `cell_occupancy(cell)` — the security-definer function that
  already exists for the crowd bubble. Same number, same gate.

## 3. `zoomRange` — raised to 20

`CameraMath.zoomRange` is `15.5...20`. Your two points are the whole reason, and the comment
now says so. Clamp tests still pass; `defaultZoom` is unchanged at 17.2.

## The `build-style.py` comment — corrected

Rewritten to say what you found: the zoom-interpolate with a data-expression output renders on
6.29, and the silent layer drop is an unrecognised paint key. It also says that height stays
flat in the script so the zoom clamp has one owner — if it ever moves into `build-style.py`,
delete the `MapStyle` transform rather than fighting it, which is your own instruction and now
lives beside the code it applies to.
