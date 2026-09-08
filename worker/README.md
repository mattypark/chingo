# chingo-presence

Live positions for the bears. One Durable Object per 600 m region; positions in memory and
nowhere else. Why this and not Supabase Realtime: [`../docs/ARCHITECTURE-PRESENCE.md`](../docs/ARCHITECTURE-PRESENCE.md).

## Running it

```bash
cp .dev.vars.example .dev.vars   # fill in; never committed
npm install
npm test                          # the rule port, same cases as the Swift engine tests
npm run dev                       # http://127.0.0.1:8787
```

Deploy needs a Cloudflare account on Workers Paid (Durable Objects are not on Free):

```bash
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
wrangler deploy
```

`SUPABASE_URL` is set in `wrangler.toml` `[vars]` for production.

## The wire

Connect once, and reconnect when you cross into another region. The phone computes
`regionId` with the same cell arithmetic the engine already has (`GeoCell`, precision × 4).

```
GET wss://<host>/v1/presence?lat=37.7596&lon=-122.4270
Authorization: Bearer <supabase access token>
```

Refused with `401` on a bad token, `403` if the profile is not onboarded or not discoverable,
`400` on a missing position.

**Send** whenever you have moved ≥ 5 m, at most once a second. Standing still, send nothing;
send the text `ping` every ~25 s and expect `pong` — that keeps you alive without waking
the object.

```json
{ "lat": 37.7596, "lon": -122.4270, "course": 312.5 }
```

`course` is optional and should be null when not genuinely moving.

**Receive**, as JSON lines:

```json
{ "t": "welcome", "region": "r6991_-22672" }
{ "t": "pos", "id": "<uuid>", "handle": "wren", "accent": 5, "lat": 37.7601, "lon": -122.4266, "course": 300, "m": 62 }
{ "t": "gone", "id": "<uuid>" }
```

A `pos` is an upsert: draw or move that bear. A `gone` removes it. You will only ever receive
a `pos` for someone the five gates allow; the server does not send what you may not see. A
`gone` may arrive for a bear you were not drawing — ignore it.

Closed with code `4000` when the same person connects again from elsewhere; a reconnect
replaces the old socket rather than leaving a ghost.

## What the server refuses

- A position faster than a plane since the last one. Dropped silently (`Plausibility`).
- More than one position a second. Dropped.
- A socket with no position and no ping for 90 s. Closed by the sweep.
