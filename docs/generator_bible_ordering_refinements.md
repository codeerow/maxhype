# Generator Bible V2 Ordering Refinements — Findings & Implementation

Date: 2026-07-29
Baseline: f78cc47 (audited build) + 557c7a2 (Generator Bible V2, tag `generator-bible-v2.0` / `generator-bible-v2.1`)
Scope: the three follow-up items from the V2 compliance audit. No changes to
scoring, slot plans, duration logic, set allocation, RNG, replacement
selection, movement caps, stimulus caps, or the exercise library.

## 1. Explicit conceptual phases (squat vs. secondary/unilateral)

### Finding

The audit was correct: `ExerciseOrderer.legsPhaseFor` folded the Bible's
phases 1–2 into a single phase (`squat | leg_press | lunge` → phase 1) and
phases 4–6 into a single isolation phase. "Squat before lunge" held only
because the preceding SECTION_PRIORITY block pass (squat = 2 < lunge = 5)
ran first and the phase regroup is stable. The same was true of "quad
isolation before hamstring isolation" (block order quads → hamstrings).

The executed web prototype (`_legsPhaseFor`, script.js:4307) uses the same
folded model, so the Flutter port was faithful to the reference — but the
Bible outranks the historical web generator, and the finer split can be
represented directly.

One **latent** deviation surfaced during analysis: within the folded phase 1,
SECTION_PRIORITY ranks `lunge` (5) ahead of `quad` (6) — and Leg Press
carries category `quad`. Had a slot plan ever co-selected a leg press and a
lunge-family movement, the lunge would have sorted **before** the leg press,
violating Bible phase 1 (squat/primary bilateral) vs. phase 2
(secondary/unilateral). Empirically this is unreachable today: across 7,200
generated Legs + Core workouts (6 durations × 4 experience levels × 300
seeds) no workout contains both. The explicit phase split removes the latent
risk entirely.

### Change

`lib/services/generator/exercise_orderer.dart` — `legsPhaseFor` now mirrors
the Bible's Legs + Core target flow one-to-one:

1. Squat / primary bilateral (`squat`, `leg_press` patterns)
2. Secondary compound / unilateral (`lunge` pattern — lunges, split squats,
   step-ups)
3. Hinge / hip thrust (per the V2.1 implementation note)
4. Quad isolation
5. Hamstring isolation
6. Other lower-body isolation (kickbacks, ab/adduction — per V2.1 note)
7. Calves
8. Core (always last; metadata-less exercises land just before core)

Every exercise's classification is unchanged — each old folded phase maps
onto a contiguous run of new phases, and the stable bucketing preserves the
incoming order — so the Bible ordering is now preserved **by construction**,
with no dependency on SECTION_PRIORITY for cross-phase guarantees.
SECTION_PRIORITY still contributes only *intra-phase* niceties the Bible
leaves unspecified (e.g. squats ahead of leg presses inside phase 1).

### Output parity proof

A/B snapshot before vs. after the change: **21,600 workouts** (3 splits × 6
durations × 4 experience levels × 300 seeds), comparing the full ordered
exercise list *and* per-exercise set counts. Result: **byte-for-byte
identical, 21,600 / 21,600.** Workout output is unchanged.

## 2. Regression tests for the Bible ordering

New file: `test/services/generator/generator_bible_ordering_test.dart`.
These tests verify the Bible, not the implementation:

- **Unit group, immune to SECTION_PRIORITY** — exercises are fed to the
  orderer with categories *unknown* to SECTION_PRIORITY / SECTION_GROUPS, so
  the block pass cannot contribute any ordering; only the phase
  classification can produce the expected order. Covers: squat before lunge;
  squat before split squat; squat before step-up; quad isolation before
  hamstring isolation; leg press before the lunge family (the latent case
  from §1); and a fully scrambled Bible flow reassembling in spec order.
  These fail if phase ordering regresses **regardless of any future
  SECTION_PRIORITY change**.
- **Generated-workout group** — asserts the same rules on real generator
  output across 2,400 configurations (all experiences × 6 durations × 100
  seeds), by library metadata only (movement pattern / category, never phase
  numbers): primary bilateral → lunge family → hinge/hip thrust, and quad
  isolation → hamstring isolation. Plus an explicit 300-seed check that
  split squats and step-ups follow every squat.

Existing `exercise_orderer_test.dart` assertions were updated to the new
phase numbering (same expected workout orders throughout).

## 3. Replacement ordering review

### Finding

Replacement is an in-place swap:
`GeneratedWorkoutRepository.replaceExercise` writes the new exercise at the
old exercise's index and touches nothing else
(`lib/repositories/generated_workout_repository.dart`). No ordering pass
runs afterwards.

Can this produce a sequence that generation-time ordering would forbid?
**Yes** — e.g. replacing a first-slot Leg Press with a Leg Extension puts an
isolation ahead of compounds. This is **intentionally permitted** and is the
documented specification: Generator Bible §Replacement System → *Ordering
Preservation* states that replacing a single exercise must not regenerate or
reorder the remainder of the workout, that generator ordering rules apply to
workout generation, and that replacement prioritizes workout identity and
session continuity. The replacement ranker also biases toward same-pattern /
same-category alternatives, so cross-phase swaps are possible but not the
preferred path.

### Decision

Ordering remains fixed after replacement — by the Bible, by design. No
behavioral change is proposed; localized reordering would require an
approved product decision and a Bible update first. The behavior is now
locked in two places:

- a doc comment on `replaceExercise` citing the Bible section;
- a regression test asserting a mid-list replacement preserves **every**
  position (`test/repositories/generated_workout_repository_test.dart`,
  "replaceExercise is an in-place swap").

## 4. No unrelated changes

Touched files:

| File | Nature |
| --- | --- |
| `lib/services/generator/exercise_orderer.dart` | Legs phase model split (ordering pass only) |
| `lib/repositories/generated_workout_repository.dart` | doc comment only |
| `test/services/generator/generator_bible_ordering_test.dart` | new Bible regression tests |
| `test/services/generator/exercise_orderer_test.dart` | phase-number updates in existing assertions |
| `test/repositories/generated_workout_repository_test.dart` | new replacement position-preservation test |

Scoring, slot plans, duration logic, set allocation, RNG, replacement
selection, movement caps, stimulus caps, and the exercise library are
untouched.

## Verification

- Full suite: **500 tests, all passing** (includes the generator invariant
  suite).
- `flutter analyze`: warning/error count unchanged vs. baseline.
- Output parity: 21,600 / 21,600 workouts identical (see §1).
