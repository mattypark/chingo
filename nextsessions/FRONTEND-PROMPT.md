# ChinGo — frontend session

You own `ios/`. The backend session owns `worker/`, `supabase/` and `scripts/`. Do not
cross that line; `docs/SESSION-FRONTEND.md` has the full rules.

## Read these first

Four handoff docs written at the end of the last session, each holding a decision rather
than a to-do:

- `docs/NEXT-STREAK-AND-PET.md` — consecutive-day streak, app icons, caring for the bear
- `docs/NEXT-PHOTOS-ON-THE-MAP.md` — photo-library access, pins where photos were taken
- `docs/NEXT-LIVE-ACTIVITIES.md` — Live Activities (blocked on project structure)
- `docs/NEXT-NFC-STICKER.md` — the NFC sticker, as a side engine

Also `docs/DESIGN.md` for the sticker language, and `docs/HANDOFF-MAP-PALETTE.md` if you
touch the basemap.

## Finish first — two things designed but not built

Both are specified in the last session's plan and both have a known obstacle:

1. **The onboarding answer slides up.** After you submit, the typed answer rises to where
   the question was, the way Bump's does. `OnboardingStep.swift` — collapse the fixed head
   gap and the question→answer gap, fade the question. **Resign focus before animating**:
   the keyboard's safe-area change will fight a hand-rolled offset. `AnswerField` needs a
   `submitted` flag; both call sites in `OnboardingFlow.swift` pass it, and the age step's
   sibling message moves with it.

2. **The map ↔ globe transition.** Matthew wants each piece of chrome to pop away and the
   new screen's chrome to pop in, staggered, rather than the system slide.
   `.fullScreenCover` gives no transition hook and `matchedGeometryEffect` cannot cross a
   presentation boundary — so replace it with a `ZStack` swap inside `MapScreen`'s existing
   stack, and give `GlobeScreen` an injected `onClose` instead of `@Environment(\.dismiss)`.
   Map chrome currently shares one `.opacity`, so each piece needs its own animation value
   to stagger. One element should genuinely fly: the home bar's globe cell → the globe
   screen's "Everyone" button, same SF Symbol, and the code already says in prose that you
   leave by the handle you came in through.

Then pick up the handoff docs in whatever order Matthew wants.

## Three constraints not to rediscover

- `ChinGoEngine/Progress.swift` argues **against** daily streaks in prose and counts
  weeks-with-a-meetup. Matthew overruled it. **Rewrite that comment**, do not delete it.
- `MapState` says XP and streak are derived and never stored. Freezes and claimed rewards
  cannot be derived — break that invariant deliberately and update the comment.
- `setAlternateIconName` always shows a system alert that cannot be suppressed through
  public API. The auto-changing lapse icon must therefore be opt-in.

## How this session works

- Verify by running it: build, launch the simulator, screenshot, look. `-seedDemo`,
  `-open globe|catch|album|profile`, `-onboardStep <name>`, `-resetOnboarding`,
  `-skyAltitude <deg>`. Animations need a short frame sequence, not one still.
- **Kill the simulator after each round** — it pegs the CPU.
- `cd ios/ChinGoDesign && swift test` — 111 tests today, keep them green.
- **Commit after every change**, authored as `Matthew Park <matthew.parkk0@gmail.com>`.
  Never push; Matthew pushes.
- Reference apps being combined: Bump/amo (map, onboarding, progressive unlock), Finch
  (gentle streaks, pet care), Pokémon GO (the street map). The purpose underneath stays:
  take pictures and remember the people you meet.
