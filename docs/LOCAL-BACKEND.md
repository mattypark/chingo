# The backend on your Mac, for nothing

What you need, what it costs, and the order. Short version: **Docker, and one script.**
Nothing here creates an account, and nothing bills.

## What it takes

| | Needed for | Cost |
|---|---|---|
| **Docker Desktop** | Postgres, Auth, PostgREST — the whole Supabase stack, via `supabase start` | free |
| **Supabase CLI** (`brew install supabase/tap/supabase`) | runs the above, applies the migrations, runs the RLS proof | free, installed |
| **Node 22** | the presence worker and its tests | free, installed |
| **`wrangler`** (installed by `npm install` in `worker/`) | runs the Durable Object locally in Miniflare — no login, no account | free |
| **Xcode** | the app | free |

Not needed until launch: a Supabase project, a Cloudflare account, `supabase-swift` in the
app, any credit card.

## Start it

```bash
./scripts/dev-backend.sh
```

That does, in order:

1. `supabase start` if it is not already up (first time pulls images; a minute or two).
2. Writes `worker/.dev.vars` and — if you do not have one — `ios/ChinGo/Secrets.xcconfig`,
   both from the local keys, both gitignored. The script never prints a key.
3. `npm install` in `worker/` the first time.
4. `wrangler dev` on `http://127.0.0.1:8787`. Ctrl-C stops the worker; Supabase keeps
   running until `./scripts/dev-backend.sh --stop`.

## Prove it

In another terminal:

```bash
./scripts/test-db.sh               # 21 RLS assertions, in a transaction that rolls back
node scripts/smoke-presence.mjs    # five fake people in Dolores Park, end to end
```

The smoke test creates six throwaway users in the local Auth, connects them to the local
worker, and asserts the rules with real sockets: a hidden person is refused at the door,
four people in a cell see nobody, a fifth arrives and everyone sees everyone, a blocked
pair never see each other, a 5 km teleport is dropped, and leaving sends `gone`. Then it
deletes the users. Zero dependencies.

## Point the app at it

`scripts/dev-backend.sh` already wrote `ios/ChinGo/Secrets.xcconfig` with the local URL and
anon key, and `ios/project.yml` now reaches it through `ChinGo/Base.xcconfig`, which does
`#include? "Secrets.xcconfig"`. Regenerate once (`cd ios && xcodegen generate`) and the
values land in Info.plist for the simulator. With no `Secrets.xcconfig` at all the include
is skipped and the app runs on seeded data — the same working state as before.

The app does not yet *talk* to any of it: there is no `supabase-swift` in the project, by
decision, until something hosted exists. What it will need, in `Sources/Services/`:

- **Auth** — Sign in with Apple → `signInWithIdToken` → a Supabase session. Local Auth
  accepts email/password too, which is what the smoke test uses.
- **Profile** — one upsert to `profiles` at the end of onboarding. `handle_available()`
  for the handle step. `delete_me()` behind a button (Apple 5.1.1(v)).
- **Presence** — one WebSocket to `/v1/presence?lat&lon` with the subprotocol
  `bearer.<jwt>`; send `{lat, lon, course}` on movement, `ping` every 25 s; draw `pos`,
  remove `gone`. Reconnect when `regionId` changes. The wire is in `worker/README.md`.

A physical phone cannot reach `127.0.0.1`; the simulator can. For a phone on the same
Wi-Fi, put the Mac's LAN address in `Secrets.xcconfig` and run `wrangler dev --ip 0.0.0.0`.

## When you do host it

Everything in `worker/` and `supabase/` deploys unchanged. The steps and the monthly numbers
are at the bottom of [`ARCHITECTURE-BACKEND.md`](ARCHITECTURE-BACKEND.md): a free Supabase
project to start, Workers Paid at $5 for Durable Objects, and `supabase-swift` only then.
