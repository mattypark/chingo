# Backend session

Owns everything that is not a screen: data, rules, release, and the App Store Connect
connection.

## What this session owns

| Area | Path |
|---|---|
| Rules engine — bond tiers, XP, presence gate, geo, camera math, age gate | `ios/ChinGoDesign/Sources/ChinGoEngine/` + its tests |
| Database — schema, RLS policies, migrations, RLS test suite | `supabase/` |
| Cloudflare Worker — map tiles, image delivery, avatar jobs | `worker/` |
| Web companion — landing, public card pages | `web/` |
| Build, release, TestFlight | `scripts/`, `docs/TESTFLIGHT.md` |
| App Store Connect via `asc-mcp` | see below |

**Does not touch** `ios/ChinGo/Sources/Features`, `ios/ChinGo/Sources/Components`, or
`ChinGoDesign` — those belong to the frontend session. If a rule needs to change shape, change
it in `ChinGoEngine` and say so; do not reach into views.

## The standing rules

- **Tests are the deliverable, not a chore.** Anything in `ChinGoEngine` is pure on purpose so
  it can be proved without a simulator. 43 tests today; a change that cannot be tested there
  probably belongs in a view.
- **RLS is the product's safety guarantee.** `./scripts/test-db.sh` must stay green. It asserts
  that a friend cannot read your memories and that nobody can read another person's presence
  row. If a policy change breaks one of those, the change is wrong.
- **Never touch `.env*` or real credentials.** Ship `.env.example`. Matthew fills the real one.
- **Commit after every change.** Never push without being asked.

---

## App Store Connect — read this before using it

This session has an `asc-mcp` server connected to Matthew's real App Store Connect account for
**HMU, INC.** It is a live, commercial Apple account with other shipped apps on it. Treat it
that way.

### Scope

Ten of thirty-three domains are enabled: `apps`, `builds`, `build_uploads`, `beta_app`,
`beta_groups`, `beta_testers`, `beta_feedback`, `pre_release`, `export_compliance`, `reviews`.

Pricing, subscriptions, in-app purchases, users, provisioning, versions, screenshots, Xcode
Cloud, analytics and webhooks are **not exposed**. The account's role still permits them at
Apple's end; the tools simply are not in this session. Do not try to widen the scope.

### What this connection is for

1. Getting a build onto TestFlight.
2. Configuring TestFlight — groups, testers, "what to test" notes, export compliance.
3. Reading what comes back: tester feedback, crash reports, Apple's review responses, and
   customer reviews once the app is public.

That is the whole remit.

### Never do these

- **Never print, echo, log, paste or commit a credential.** The `.p8` lives at `~/.keys/`, the
  config at `~/.config/asc-mcp/companies.json`, the IDs at `~/.config/asc-mcp/asc.env`. Do not
  read them out, do not copy them into the repo, do not include them in a commit message or a
  screenshot. If one is ever exposed, say so immediately and tell Matthew to revoke the key —
  that comes before finishing whatever else was in progress.
- **Never submit for App Store release.** TestFlight beta review only. Publishing the app is
  Matthew's decision and his click, and it is not reversible on his timetable.
- **Never do anything that moves money.** No pricing, no in-app purchases, no subscriptions,
  no promo codes, no offers. These are out of scope and out of reach; keep it that way.
- **Never delete.** Builds, groups, testers, feedback — deleting is destructive and rarely
  urgent. Ask.
- **Never enable a public TestFlight link without being asked.** A public link invites
  strangers to install the app; that is a distribution decision, not a build step.
- **Never change the bundle ID, app name, or primary language.** Bundle ID especially — it
  cannot be changed after a build exists and would mean an entirely new app record.
- **Never touch the other apps on this account.** Fitti, findi, Chef AI, Gourmet AI and the
  rest are live products. Filter by `com.matthewpark.chingo`; if a tool would act across the
  team, do not run it.
- **Never add or remove App Store Connect users, or change anyone's role.**

### Always do these

- **Read freely, write deliberately.** Listing builds, reading feedback, checking processing
  state: go ahead. Anything that changes state on Apple's side: say what it will do first.
- **Quote Apple verbatim.** When a build is rejected or flagged, paste the actual message
  rather than a summary of it. The wording is what maps to a guideline number.
- **Redact tester personal data.** Feedback contains real people's names, emails and device
  details. Do not put them in commit messages or files.
- **Never invent status.** If a build is still processing, say it is still processing. Do not
  guess at what Apple will say.

---

## The prompt for this session

```text
You are the backend session for ChinGo, at
~/Downloads/current-projects/appscurrent/chingo.

Read docs/SESSION-BACKEND.md first and follow it — especially the App Store Connect
section. Then read CLAUDE.md and docs/DESIGN.md for context.

You own: ChinGoEngine and its tests, supabase/, worker/, web/, scripts/, and the
App Store Connect connection via the asc-mcp server. You do not edit SwiftUI views,
Features/, Components/, or ChinGoDesign — the frontend session owns those.

The asc-mcp server is connected to a real, live Apple account with other shipped
apps on it. You may get builds onto TestFlight, configure TestFlight, and read
feedback, crash reports and review responses. You may not submit for App Store
release, touch anything involving money, delete anything, enable a public link,
change the bundle ID, or act on any app other than com.matthewpark.chingo. Never
print or commit a credential.

Commit after every change. Never push unless asked.

Current state: 43 engine tests and 13 RLS assertions pass. Build 0.1.0 (1) is
exported and ready. Not yet uploaded to TestFlight.

Start by telling me what you can see in App Store Connect for ChinGo and what is
blocking the first TestFlight build.
```
