# Which backend, for this app

Asked directly: *is Supabase the right backend for ChinGo, or would all-Cloudflare — or
something else — be better?* The live layer is already Cloudflare
([`ARCHITECTURE-PRESENCE.md`](ARCHITECTURE-PRESENCE.md)); this is about everything with a row.

## What the app actually needs from a database

Read off the schema and the rules, not off a feature list:

1. **Constraints that make bad states unrepresentable.** A bond is one row with
   `check (lo < hi)` — a one-sided friendship cannot be stored. A catch is a state machine.
   The ledger is append-only. These are SQL constraints, not application checks.
2. **Row-level safety that can be proved.** 21 assertions in `scripts/test-db.sh` show
   that a friend cannot read your memories and nobody can read anyone's presence row. The
   product's privacy claim rests on those tests, and they are written in SQL against
   Postgres row-level security.
3. **Geospatial queries.** `memories.at` is a `geography(point)` with a GiST index for
   "surface within 150 m"; `sponsored_zones.area` is a polygon for "did they visit". PostGIS.
4. **Native Sign in with Apple**, cheap to 100 k monthly users.
5. **A local stack** the tests run against without a cloud account. `supabase start` does
   this today in Docker.
6. **Cost at 10,000 concurrent** — realistically ~50 k monthly active.

## The candidates

| | Supabase | All-Cloudflare (D1) | Neon | Convex | Firebase |
|---|---|---|---|---|---|
| Engine | Postgres | SQLite | Postgres | Document, TS functions | Document |
| Constraints (1) | ✅ native | ✅ SQLite has CHECK / PK | ✅ | ❌ in code | ❌ in code |
| RLS proof (2) | ✅ **exists today** | ❌ no RLS — rewrite as Worker code + integration tests | ✅ RLS with JWT via Neon Auth | ❌ | Security Rules, a different language, untested |
| PostGIS (3) | ✅ | ❌ no extensions; R*Tree at best, hand-rolled bbox on cell ids | ✅ | ❌ | ❌ geohash libraries |
| Apple sign-in (4) | ✅ included, 100 k MAU on Pro | ❌ **no user-auth product**; Clerk (10 k free, then $0.02/MAU → ~$800/mo at 50 k) or verify Apple's JWT yourself and mint sessions | ✅ Neon Auth, 60 k free / 1 M paid | ✅ via providers | ✅ 50 k free |
| Local stack (5) | ✅ `supabase start` | ✅ `wrangler dev` + local D1 | ⚠️ branches, no offline | ⚠️ `convex dev` needs the cloud | ✅ emulators |
| Client API | PostgREST + supabase-swift | Worker routes you write | Worker → Neon HTTP driver (no client REST) | Convex client | Firebase SDK |
| Cost at 10 k concurrent | **~$40/mo** (Pro $25 + Small $15; 100 k MAU incl.) | **~$5/mo** + auth (see above) | ~$77/mo for 1 CU always-on ($0.106/CU-hr) + storage | $25/dev + function calls: bears alone ≈ 2 B calls/mo ≈ **$4,000** | Firestore reads/writes at fan-out scale; RTDB egress ≈ $1,900 (see presence doc) |
| What you throw away | nothing | the 21-assertion proof, PostGIS, the schema as written | PostgREST; adds a Worker in front of every read | everything | everything |

Sources: [Supabase pricing](https://supabase.com/pricing) · [D1 limits](https://developers.cloudflare.com/d1/platform/limits/) · [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/) · [Neon pricing](https://neon.com/pricing) · [Convex pricing](https://www.convex.dev/pricing)

## The two that are actually on the table

**Supabase + Cloudflare Durable Objects** — what is built. Postgres holds every row and
proves who may read it; a Durable Object holds every live position and never writes one
down. Two vendors, each doing the thing it is for. ~$45 / month all-in at 10 k concurrent.

**All-Cloudflare** — the one-vendor version. D1 for rows, Durable Objects for live, Workers
for the API, and Sign in with Apple verified by hand (Apple publishes a JWKS; the worker
already verifies Supabase's the same way — it is forty lines either way). ~$5 / month.

What all-Cloudflare costs that the price does not show:

- **The safety proof moves out of the database.** D1 has no row-level security. Every rule
  in `0002_rls.sql` — a friend cannot read your memories, nobody reads presence, strangers
  are not browsable, a catch cannot be forged — becomes a `WHERE` clause a Worker must
  remember to add. The 21 assertions would be rewritten as integration tests against the
  Worker, and a forgotten clause is a data leak rather than a `permission denied`.
- **PostGIS goes.** Memories-within-150 m becomes a bounding box on the cell ids the app
  already computes, which is fine. Polygon containment for sponsored zones is hand-rolled.
- **Auth is yours to maintain.** Token refresh, revocation, "sign in with Apple" private
  relay emails, account deletion with Apple's server-to-server notifications. Supabase
  does all of that; a Worker does what you wrote.
- **Nothing to migrate to.** 10 GB per D1 database is years of ChinGo, but there is no
  "bigger instance" — past that it is sharding by hand.

Saves about $35 a month. At 10 k concurrent that is the price of one coffee a day for
keeping the privacy guarantee in a place where a test can prove it.

## Recommendation

**Stay on Supabase for rows; Durable Objects for the live layer.** The deciding factor is
not price, it is that the product's whole claim — *we never expose where you are* — is a
database property today, with a test suite. Moving to D1 means re-asserting it in
application code, which is where every app in the README got it wrong.

Reconsider if any of these becomes true:

- Supabase Pro's compute stops being enough and Medium ($60) is the next step. At that
  point compare Neon's per-hour compute honestly.
- Cloudflare ships a user-auth product or row-level security for D1. Either one removes a
  real objection.
- The team wants one bill and one dashboard more than it wants the proof. That is a
  legitimate preference; it should be chosen knowingly.

## What "set it up" means, when you do

Nothing here needs to exist for local development. When it does:

1. **Supabase** → new project, Free tier is fine to start. Then, from this repo:
   `supabase link --project-ref <ref>` · `supabase db push` (applies 0001–0003) · Dashboard
   → Authentication → Providers → Apple → bundle id `com.matthewpark.chingo`. Paste the URL
   and anon key into `ios/ChinGo/Secrets.xcconfig` (gitignored; the `.example` shows the
   shape). Pro + Small when there are real users.
2. **Cloudflare** → Workers Paid ($5). `wrangler login` · `wrangler secret put
   SUPABASE_SERVICE_ROLE_KEY` · set `SUPABASE_URL` in `worker/wrangler.toml` ·
   `wrangler deploy`.
3. Only then does `supabase-swift` earn its place in `ios/project.yml`.
