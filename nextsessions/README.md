# Next sessions

Two sessions run in parallel on ChinGo. Open a terminal for each, paste the matching prompt,
and leave them in their lanes.

| | Owns | Prompt |
|---|---|---|
| **Frontend** | Screens, components, design system, mascot, assets | [`FRONTEND-PROMPT.md`](FRONTEND-PROMPT.md) |
| **Backend** | Rules engine, database, worker, release, App Store Connect | [`BACKEND-PROMPT.md`](BACKEND-PROMPT.md) |

Full detail lives in [`../docs/SESSION-FRONTEND.md`](../docs/SESSION-FRONTEND.md) and
[`../docs/SESSION-BACKEND.md`](../docs/SESSION-BACKEND.md). The prompts point at those, so the
rules stay in one place rather than being duplicated into a prompt that then drifts.

## Why two, and why this split

The line is drawn where two sessions would otherwise collide. Frontend owns everything a
person looks at; backend owns the rules, the data, and Apple. Neither reaches into the other.

A screen that needs a rule which does not exist — a new tier threshold, a different XP curve —
**asks the backend session for it** rather than computing it in a view. That is the whole point
of the split: rules stay in `ChinGoEngine`, which is pure and testable without a simulator, so
they can be proved rather than eyeballed.

## Before you paste

- Both sessions commit after every change and **never push unless asked**.
- The backend session is connected to a **live commercial Apple account**. Its prompt carries
  hard limits; do not loosen them when editing the prompt.
- Update the "current state" line in each prompt when it goes stale. A prompt that claims 43
  tests when there are 60 teaches the session that the file is not to be trusted.
