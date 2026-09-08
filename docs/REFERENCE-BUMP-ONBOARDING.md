# Reference: Bump's onboarding, frame by frame

Matthew recorded Bump's first run on 8 September 2026 and asked that ours land close to it.
The recording is 37s at 120fps; frames are extracted every 0.1s to
`~/Documents/Reference images/chingo-onboarding-ref/` (373 of them, plus a contact sheet at
`sheet1.png` and the name screen at `name_full.png`).

The recording lives outside the repo on purpose — it is 3600×2338 and belongs with the other
reference material rather than in git.

## The order Bump goes in

1. **Splash** — the wordmark on a saturated colour field, nothing else.
2. **Name** — two stacked fields, first and last.
3. **Phone number**, then a **6-digit code**.
4. **A picture of you.**
5. **Permissions**, one screen, each row firing its own system alert: contacts,
   notifications, location.
6. **"Find your 3 best friends."**
7. **The globe**, then the city map.

## What the name screen actually does

The screen Matthew pointed at, measured off `name_full.png`:

- The question — "What's your name?" — is small, grey, centred, and carries no heading weight.
- **Two fields, stacked, centred**, set far larger than anything else on screen. Placeholders
  are the same face as the answer, only grey: "First name" over "Last name".
- **No field chrome at all.** No box, no underline, no label. The answer is the content.
- The pair sits in the **middle of the space above the keyboard**, not near the top.
- The keyboard is up from the moment the screen arrives, and the return key moves to the
  second field rather than dismissing.
- Bump's ground is warm cream. Ours is white — Matthew's call, and the one deliberate
  departure on this screen.

## What we took, and what we did not

**Took:** the two stacked fields, the centred block, the invisible field, the quiet question,
the keyboard up on arrival with return handing over.

**Did not take:**

- **Phone number and SMS code.** ChinGo is local-first and has no account; there is nothing to
  verify against, and asking for a number before the app has done anything is the single most
  expensive thing you can ask for.
- **Contacts.** The permissions screen deliberately does not ask. The whole premise is that you
  catch people you are standing next to, so suggesting friends from a phone book would be
  suggesting them by the one method the app exists to replace.
- **"Find your 3 best friends."** Same reason. Ours hands over your handle instead, which is
  how the first friendship in this app actually starts.

**Changed:** surname is optional here. A required surname is a form; this is an introduction,
and plenty of people give one name when they meet somebody.

## The transition

Bump advances vertically. Ours did too until it did not: the flow had picked up a horizontal
slide, which reads as a pager — it says the screens sit beside each other and you can swipe
back. This flow has no back, because the age gate settles before anything is asked for. It is
vertical again, and it agrees with the answer rising into the question's place rather than
fighting it.
