# Live presence at 10,000 people — what carries the bears

The question was what system lets ChinGo run smoothly with ten thousand people on it at once.
The answer is specific to what a bear actually is: a position that is **live, transient, and
never stored**. That shape rules out most of the obvious choices on cost alone.

## The load, stated honestly

Assumptions, so the arithmetic can be argued with:

| | |
|---|---|
| Concurrent people | 10,000 |
| Walking at any moment | 40% — 4,000 |
| Position sent while walking | every 5 s, or on ≥5 m moved. A walking person covers 7 m in 5 s; the bears interpolate |
| Position sent while standing | none. Liveness is a protocol ping, which costs nothing (below) |
| People who can see you | ~8 in a full cell. The floor is 5; a busy street is more |

That gives **800 positions per second inbound**, and each one fans out to the ~8 people who can
see it: **~7,200 delivered messages per second**. Per month, ~18.7 billion.

Standing still costs nothing by design. That is not an optimisation, it is the product: a bear
that is not moving does not need to be re-drawn, and a phone in a pocket should not be talking.

## The candidates

### Supabase Realtime Broadcast — the obvious one, and the wrong one

The project already runs on Supabase, so this was the first thing measured.

Limits per plan ([docs](https://supabase.com/docs/guides/realtime/limits)):

| | Free | Pro | Pro, no spend cap | Team / Enterprise |
|---|---|---|---|---|
| Concurrent connections | 200 | 500 | 10,000 | 10,000+ |
| Messages per second | 100 | 500 | **2,500** | 2,500+ |

An event is counted **both when sent and when delivered** — one broadcast to 8 people is 9
events. ChinGo's 7,200/s is three times the Pro-no-cap ceiling, so the plan is Enterprise
before day one.

Pricing ([docs](https://supabase.com/docs/guides/realtime/pricing)): **$2.50 per million
messages** past 5 million, **$10 per 1,000 peak connections** past 500.

- Messages: 18.7 B / month × $2.50 / M ≈ **$46,700 / month**
- Connections: 9,500 over quota ≈ $95 / month

The engine can do it — Supabase's own benchmarks show 224,000 msgs/s at 32,000 users
([benchmarks](https://supabase.com/docs/guides/realtime/benchmarks)). It is the meter that
kills it. Even if every assumption above is 10× too pessimistic, that is $4,700 a month for
a free app. Ably and PubNub price the same way and land in the same place.

### Firebase Realtime Database

Handles 200,000 concurrent, so 10,000 is fine. Billed per GB downloaded at $1/GB. 18.7 B
messages × ~100 bytes ≈ 1.9 TB / month ≈ **$1,900 / month**, plus it would put a second
database with its own security-rules language beside the Postgres one that already has 21
RLS assertions. No.

### Cloudflare Durable Objects — the right shape

`worker/` was already reserved for Cloudflare. A Durable Object is a single-threaded stateful
instance addressed by name, with WebSocket support that **hibernates**: the object leaves
memory between messages while its sockets stay connected, and a hibernated object is not
billed for time ([docs](https://developers.cloudflare.com/durable-objects/best-practices/websockets/)).

One object per **region** — a 4 × 4 block of `GeoCell`s, about 600 m square. A phone connects
to the object for the region it is standing in. The object holds every position in memory and
nowhere else, applies the presence rule per pair, and pushes to each viewer only what that
viewer is allowed to see.

Pricing on Workers Paid ([docs](https://developers.cloudflare.com/durable-objects/platform/pricing/)):

| | Included | Then | ChinGo at 10k |
|---|---|---|---|
| Requests | 1 M / month | $0.15 / M | 800 msgs/s **÷ 20** (incoming WebSocket messages are billed at 20:1) = 40 req/s ≈ 104 M / month ≈ **$15.50** |
| Outgoing WebSocket messages | — | **free** | 7,200/s ≈ **$0** |
| Duration | 400,000 GB-s | $12.50 / M GB-s | ~2 ms of work per message × 800/s × 128 MB ≈ 530 k GB-s / month ≈ **$1.60** |
| Storage | 5 GB | — | nothing is stored ≈ **$0** |
| Workers Paid base | | | **$5** |

**≈ $25 / month at 10,000 concurrent.** Wrong by 10× on duration and it is $40.

Limits that matter ([docs](https://developers.cloudflare.com/durable-objects/platform/limits/)):
a soft **1,000 requests/s per object**. A region at a festival with 1,000 people all walking
would send 200/s. Fine. A region is also the only unit that can get hot, and it is 600 m
across, so "hot" has a physical ceiling.

## Why this is also the safest shape

The engine rule `Presence.livePosition(for:)` has five gates. Three of them are enforced by
the *topology* here rather than by a check that could be skipped:

- **Reciprocity, both directions.** You are only in the object if you connected, and
  connecting is how you become visible. A hidden person is not in the room and cannot listen
  from the corridor. The worker also refuses the connection unless `profiles.discoverable` is
  true, so the database's idea of "hidden" and the room's agree.
- **Never stored.** The object keeps positions in memory only. There is no table, no log, no
  row for RLS to protect, because there is nothing to protect. Postgres `presence` keeps its
  coarse cell for the occupancy count and the future friends server — exactly as before, and
  `test-db.sh` still proves nobody can read it.
- **Blocks.** At connect, the worker asks `block_relations_for()` with the service role and
  hands the object the list. Neither party in a block ever appears to the other, and the list
  never reaches a client.

The other two — the k-anonymity floor and the radius with hysteresis — are the same function
ported to `worker/src/rules.ts`, with the same tests.

## What it does not do yet

- **Region edges.** Someone 100 m from you across a region boundary is in a different object
  and invisible. Fix: objects gossip with their eight neighbours over RPC. Not in v1; the
  regions are 600 m and the radius is 150 m, so it bites at the edges only.
- **Hysteresis across hibernation.** The "who was I already showing" sets live in memory and
  are empty after a wake. Worst case: one flicker for someone standing between 150 m and
  200 m away. A `gone` on disconnect is sent to everyone regardless, so nobody is left drawn.
- **Profile lookup per connect** is one PostgREST read. At 10k people churning once a minute
  that is ~170 reads/s on Postgres, which a Small instance handles but a Micro will feel.

## The rest of the stack at 10,000

| Layer | Choice | Why it holds |
|---|---|---|
| Database | Supabase **Pro + Small compute** (~$40 / month) | The only steady write is the coarse cell on cell change: 4,000 walkers crossing a 150 m cell every ~107 s ≈ **37 writes/s**. Reads go through PostgREST's pool. |
| Auth | Supabase Auth, native Sign in with Apple | 100 k MAU on Pro. The worker verifies the same JWT at the edge via the project's JWKS, so nothing round-trips to Auth per message. |
| Map tiles | OpenFreeMap public CDN today | Free and keyless, but their own guidance is to self-host past hobby scale. The move is PMTiles on R2 behind this same worker; `.env.example` already names the buckets. Not yet needed. |
| Photos | On-device only | `memories.local_asset_id` is a PhotoKit identifier. Nothing to scale. |

## Decision

Durable Objects for the live layer; Supabase for everything with a row. The worker is in
`worker/`, the rule port and its tests are in `worker/src/rules.ts` and `worker/test/`, and
the wire protocol is in `worker/README.md`.
