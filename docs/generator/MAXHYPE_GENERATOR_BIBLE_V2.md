# MaxHype Generator Bible (Source of Truth) — Version 2

**The MaxHype Generator Bible is the canonical specification for MaxHype.**

It supersedes implementation details once behavioral parity has been achieved. This document distinguishes historical migration guidance from current canonical generator rules.

---

## Table of Contents

- Purpose
- Core Generator Philosophy
- Generator Architecture
  - Generator Flow (High-Level)
- Core Routines
  - Supported Routines
    - PPL
    - PPL + Upper/Lower
- Duration Tiers
- Experience Levels
- Identity System
  - cardIndex Is Canonical
- Slot Architecture
- Ordering Philosophy
  - Push
  - Pull
  - Legs + Core
    - Implementation Note
- Set Architecture
  - General Philosophy
- Focus / Exclude Overlay System
  - Focus
  - Exclude
- Generator Rules
  - Wall Sit
  - Bench Dips / Bodyweight Restrictions
- Similarity Smoothing (Phase 16)
- Metadata Differentiation (Phase 17)
- Press Ecosystem Balancing (Phase 18)
- Support-Profile Diversity
- Replacement System
  - Philosophy
    - Ordering Preservation
  - Replacement Sorting
  - Replacement Intelligence
- Recovery / Readiness System
  - Philosophy
  - Current Recovery Architecture
  - Baselines
  - Workload Multiplier (Phase 19)
  - Readiness States
- Audit Architecture
  - Key Audits
    - Structural / Ecosystem
    - Similarity / Realism
    - Replacement
    - Recovery
- Debug Architecture
- Non-Negotiable Invariants
  - Generator
  - Replacement
  - Recovery
  - Audits
- Current Generator Status
- Developer Guidance
  - Authority Hierarchy
  - Historical Migration Rule
  - Current Canonical Rule
- Final Philosophy
- Programming Advisory System
  - Authority
  - Purpose
  - Duration Advisory Philosophy
    - 45 Minutes
    - 60 Minutes
    - 75 Minutes
    - 90 Minutes
    - 105–120 Minutes
  - Experience-Level Advisory Philosophy
    - None / Beginner
    - Intermediate
    - Advanced
  - Recovery Advisory Philosophy
    - Expected Behavior
    - Acceptable
    - Warnings
    - Philosophy
  - Audit Interpretation Philosophy
    - True Structural Danger Signals
    - Soft Realism Warnings
    - Philosophy
  - Manual Review Philosophy
  - Long-Term Generator Philosophy
- Future Evolution Philosophy
- Version 2.1 Clarifications

---

## Purpose

This document defines the authoritative architecture, rules, philosophy, and invariants of the MaxHype

workout generator.

The generator is NOT a random workout builder. It is a structured hypertrophy programming engine

designed to create believable bodybuilding-style training sessions across:

- PPL
- PPL + Upper/Lower
- Multiple duration tiers
- Multiple experience tiers
- Focus/exclude overlays
- Replacement flows
- Recovery/readiness systems

This document exists so future developers:

- do not accidentally rewrite core architecture
- do not destabilize the ecosystem
- understand WHY systems exist
- preserve generator identity during Flutter/mobile migration

## Core Generator Philosophy

MaxHype is built around these principles:

1. Compound-before-isolation hierarchy
2. Structured hypertrophy realism
3. Slot-driven architecture
4. Controlled variation
5. Stable anchors
6. Fatigue-aware flow
7. Environment/stimulus diversity
8. Session identity
9. Realistic replacement behavior
10. Human-coach feel over pure randomness

The goal is:

"This feels like a real intelligently programmed bodybuilding session."

NOT:

"This maximizes exercise uniqueness."

## Generator Architecture

### Generator Flow (High-Level)

1. Select routine structure
2. Build slot template
3. Resolve anchor compounds
4. Fill required movement/stimulus coverage
5. Apply scoring + penalties + realism smoothing
6. Enforce ordering
7. Allocate sets
8. Apply focus/exclude overlays
9. Run repair/sanitization passes
10. Persist by cardIndex

## Core Routines

### Supported Routines

#### PPL

- Push
- Pull
- Legs + Core

#### PPL + Upper/Lower

- Push
- Pull
- Legs + Core
- Upper
- Lower

## Duration Tiers

Supported durations:

- 45
- 60
- 75
- 90
- 105
- 120

Generator behavior changes by duration:

- exercise count
- set allocation
- slot requirements
- realism balancing
- support-profile diversity
- long-session row balancing
- recovery intensity

## Experience Levels

Supported experience tiers:

- none
- beginner
- intermediate
- advanced

Experience affects:

- equipment preference
- allowed exercises
- stability demand
- machine/freeweight weighting
- replace-only gating
- advanced compound bias

## Identity System

### cardIndex Is Canonical

IMPORTANT:

cardIndex is the canonical identity system everywhere.

Never use:

- split name
- workout title
- Push/Pull labels

for persistence identity.

All state must remain keyed by cardIndex:

- session state
- history
- completion
- replacement state
- recovery
- overlays

Repeated split names MUST remain independent.

Example:

Push (cardIndex 0) Push (cardIndex 3)

These are NOT the same workout.

## Slot Architecture

The generator is SLOT-FIRST.

This is one of the most important architectural decisions.

Exercises are NOT selected randomly.

The generator:

- defines structural roles first
- fills those roles second

Examples:

- primary chest compound
- vertical pull anchor
- squat anchor
- secondary row
- rear delt isolation
- hamstring curl
- calves
- core

Slot structure must remain stable.

DO NOT rewrite slot architecture casually.

## Ordering Philosophy

### Push

Target flow:

1. Chest compounds
2. Chest isolation
3. Shoulder compounds
4. Shoulder isolation
5. Triceps

Compounds must appear before isolations.

### Pull

Target flow:

1. Vertical pull anchor
2. Heavy row
3. Secondary row/stretch row
4. Rear delt/trap work
5. Biceps
6. Support/accessory

### Legs + Core

Target flow:

1. Squat/primary bilateral
2. Secondary compound/unilateral
3. Hinge
4. Quad isolation
5. Hamstring isolation
6. Calves
7. Core

Core should generally appear LAST.

#### Implementation Note

Hip thrusts and glute bridges are considered compound hip-hinge/glute movements and belong in Phase 3 alongside hinge-pattern compounds.

Kickbacks, hip abduction, and hip adduction are considered isolation movements and belong within the isolation phase together with quad and hamstring isolation work.

Within the isolation phase, quad isolation should generally precede hamstring isolation, followed by other lower-body isolation work unless a future approved product decision specifies otherwise.

This addition exists only to remove ambiguity.

It does not change generator philosophy.

## Set Architecture

Sets are allocated AFTER exercise generation.

This is critical.

Generator selection and set allocation are separate systems.

Do not collapse them together.

### General Philosophy

- Compounds receive more sets
- Secondary compounds moderate
- Isolation/accessory lower
- Duration scales total workload
- Long sessions should feel fuller without becoming absurd

## Focus / Exclude Overlay System

IMPORTANT:

Focus/exclude overlays are NOT baseline generation.

They are applied AFTER the base workout exists.

### Focus

Supports:

- slight focus
- strong focus

Behavior:

- adds sets
- may add drop sets
- should preserve generator structure

Strong focus:

- final matching exercise may gain drop-set behavior

### Exclude

Excluded muscles:

- should not appear in generation
- should not appear in replacement pools
- should remain respected throughout overlays

## Generator Rules

### Wall Sit

Wall Sit is REPLACE-ONLY.

It must:

- NEVER auto-generate
- appear ONLY in replacement picker pools

Architecture:

- generatorExclude = true
- replaceOnly = true
- replacement pools explicitly bypass generatorExclude for replaceOnly exercises

### Bench Dips / Bodyweight Restrictions

Bench Dips and many bodyweight movements:

- should not normally auto-generate
- may appear only in intentional contexts
- may remain available in replacement flows if explicitly allowed

## Similarity Smoothing (Phase 16)

Goal: Reduce unrealistic clustering WITHOUT destabilizing the generator.

Important:

- penalties are soft
- anchors remain protected
- valid bodybuilding pairings remain allowed

This system operates AFTER core structure.

Examples of clustering handled:

- excessive press stacking
- duplicate row environments
- same stimulus overload
- lunge duplication
- repeated same-axis triceps work

## Metadata Differentiation (Phase 17)

Goal: Prevent different exercises from collapsing into identical stimuli.

Examples:

- Tripod DB Row
- Bench Braced DB Row
- DB Row

These are NOT identical.

Metadata dimensions include:

- support profile
- torso stability
- unilateral vs bilateral
- stretch bias
- resistance curve
- grip width
- elbow path
- machine path

This system improves realism intelligence.

## Press Ecosystem Balancing (Phase 18)

Goal: Reduce excessive press-environment concentration.

This is NOT:

- anti-bench logic
- anti-press logic

Instead:

- too many similar press environments receive soft environmental penalties
- diversity is encouraged naturally

Examples:

- freeweight_horizontal
- machine_horizontal
- machine_incline
- fly_open_chain
- cable_press

Important:

- anchor compounds remain protected
- penalties remain lightweight

## Support-Profile Diversity

Goal: Improve perceived training texture.

Humans perceive:

- support style
- torso demand
- stability feel

not just muscles.

Examples:

- unsupported_freeweight
- chest_supported
- hand_braced_unilateral
- seated_cable
- machine_supported
- hanging_bodyweight

This is primarily observational/audit-driven.

## Replacement System

### Philosophy

Replacement is NOT regeneration.

Replacing one exercise should:

- affect only that exercise
- preserve workout identity
- preserve cardIndex isolation
- preserve session state
- preserve PR/history integrity

#### Ordering Preservation

Replacement preserves the existing workout structure and exercise positions.

Replacing a single exercise should not regenerate or reorder the remainder of the workout unless a future approved product decision explicitly introduces localized reordering.

Generator ordering rules apply to workout generation.

Replacement prioritizes workout identity and session continuity.

This documents the current intended behavior and removes ambiguity for future compliance audits.

### Replacement Sorting

Current sort hierarchy:

1. historyFrequency
2. movement-pattern affinity
3. equipment continuity
4. stable-first
5. alphabetical

### Replacement Intelligence

The replacement system prefers:

- same movement pattern
- same category
- same muscle + joint pattern
- same equipment family

BUT:

- valid alternatives remain allowed
- no hard restrictions

Example:

Replacing Leg Extension should prefer:

- Hack Squat
- Leg Press
- other quad/knee-extension work

before:

- lunges

## Recovery / Readiness System

### Philosophy

Recovery is:

- muscle-based
- workload-sensitive
- bottleneck-driven

NOT:

- split-name based
- whole-body only

### Current Recovery Architecture

Storage:

- maxhype-history

Aggregates:

- last trained timestamp
- working sets
- duration

Recovery calculation:

recoveryTime = baseHours × durationMultiplier × workloadMultiplier

### Baselines

Upper/Core:

- 36h baseline

Lower Body:

- 60h baseline

### Workload Multiplier (Phase 19)

Light sessions:

- recover faster

Heavy sessions:

- recover slower

Multiplier range:

- 0.85× to 1.25×

12 working sets:

- neutral baseline

### Readiness States

- <70% = Still Recovering
- 70–89% = Almost Ready
- ≥90% = Ready to Train

## Audit Architecture

MaxHype includes extensive audit systems.

These are CORE infrastructure.

Do NOT remove them.

### Key Audits

#### Structural / Ecosystem

- auditGeneratorEcosystemHealth
- auditFullGeneratorHealth
- auditWeeklyStimulusCoverageIntegrity

#### Similarity / Realism

- auditClusterRealism
- auditHighSimilarityPairs
- auditSupportProfileClustering

#### Replacement

- auditReplacementFlowIntegrity
- debugReplacementPickerOrder

#### Recovery

- auditRecoveryReadinessIntegrity

## Debug Architecture

Centralized debug flags exist.

Examples:

- DEBUG_GENERATOR
- DEBUG_SIMILARITY
- DEBUG_PRESS_ECOSYSTEM
- DEBUG_RECOVERY
- DEBUG_REPLACEMENT
- DEBUG_AUDITS

Runtime overrides supported:

window.DEBUG_SIMILARITY = true;

Audit outputs should remain visible even when debug flags are false.

## Non-Negotiable Invariants

DO NOT BREAK:

### Generator

- slot-first architecture
- compound-before-isolation
- anchor protection
- cardIndex identity
- repeated split independence
- focus/exclude overlay separation
- set allocation separation

### Replacement

- replacement must NOT regenerate workout
- cardIndex isolation required
- completed workouts remain read-only
- Wall Sit remains replace-only

### Recovery

- clamping [0,100]
- missing-history defaults to READY
- repeated split safety
- bottleneck logic

### Audits

- preserve ecosystem observability
- preserve PASS/WARN/FAIL outputs
- preserve console.table diagnostics

## Current Generator Status

Current state:

- structurally stable
- commercially believable
- realism-focused
- mature replacement system
- mature generator architecture
- strong audit tooling
- premium hypertrophy feel

The remaining frontier is:

- coaching feel
- emotional UX
- weekly variation feel
- premium mobile experience
- onboarding polish
- dopamine loops
- charts/history
- recovery visualization
- animations/haptics

NOT:

- generator survivability
- massive architecture rewrites

## Developer Guidance

### Authority Hierarchy

When implementation questions or conflicts arise, use the following order of authority:

1. Approved Product Decisions
2. MaxHype Generator Bible
3. Programming Advisory System
4. Historical Web Generator (reference only)
5. Flutter implementation

Flutter follows the Generator Bible.

The Generator Bible does not follow Flutter.

The historical web generator exists only as a reference after behavioral parity has been accepted.

Any intentional deviation from the Generator Bible should be documented as an approved product decision.

This section exists to eliminate ambiguity for future development and audits.

### Historical Migration Rule

During the Flutter migration, the legacy web implementation served as the behavioral source of truth.

Its purpose was to ensure Flutter produced identical workout generation before any architectural improvements were made.

### Current Canonical Rule

Once behavioral parity has been accepted by the product owner, the MaxHype Generator Bible and all subsequently approved product decisions become the canonical specification.

The legacy web implementation thereafter becomes historical reference material only.

Future development should follow the Generator Bible rather than undocumented implementation details.

Any intentional deviation from the Generator Bible must be documented as an approved product decision.

## Final Philosophy

MaxHype should feel like:

a premium bodybuilding coach built into an app

NOT:

a random exercise generator.


---

## Programming Advisory System

### Authority

The Programming Advisory System documents coaching philosophy and long-term programming intent.

Unless explicitly stated otherwise, these are advisory guidelines rather than mandatory generator constraints.

Generator behavior should increasingly align with these principles over time while preserving architectural stability.

Structural Generator Bible rules always take precedence over advisory guidance.

### Purpose

The advisory system exists to:

- preserve realistic hypertrophy programming
- prevent unrealistic user expectations
- guide future tuning decisions
- explain why some generator outcomes are intentionally allowed

These are NOT hard generator constraints.

They are:

- realism guidelines
- fatigue heuristics
- coaching expectations
- ecosystem interpretation rules

IMPORTANT:
The generator should feel:

> intelligently coached

NOT:

> mathematically perfect.

Some realism overlap is acceptable and even desirable in advanced bodybuilding programming.

---

### Duration Advisory Philosophy

#### 45 Minutes

##### Expected Feel

- efficient
- compound-dominant
- minimal fluff
- high exercise efficiency

##### Expected Characteristics

- lower exercise count
- tighter movement selection
- fewer secondary accessories
- minimal redundancy

##### Acceptable

- aggressive compound prioritization
- limited accessory diversity
- highly compressed sessions

##### Warnings

- too many isolations
- excessive support work
- multiple redundant rows/presses
- excessive machine clutter

##### Philosophy

45-minute sessions should feel:

> efficient and purposeful

NOT:

> incomplete or random.

---

#### 60 Minutes

##### Expected Feel

- balanced
- mainstream hypertrophy
- sustainable volume

##### Expected Characteristics

- strong primary compounds
- moderate accessory work
- realistic gym-session pacing

##### Acceptable

- moderate movement diversity
- standard bodybuilding structure
- balanced Push/Pull/Legs identity

##### Warnings

- over-specialization
- excessive clustering
- inflated exercise count

##### Philosophy

60 minutes represents:

> default commercial hypertrophy programming.

---

#### 75 Minutes

##### Expected Feel

- enthusiast bodybuilding
- fuller hypertrophy exposure
- more secondary stimulus variety

##### Expected Characteristics

- expanded accessory work
- more secondary compounds
- clearer specialization feel

##### Acceptable

- 2–3 row environments on Pull
- layered chest/shoulder exposure
- multiple leg stimulus environments

##### Warnings

- excessive same-support-profile clustering
- excessive spinal fatigue stacking
- machine overconcentration

##### Philosophy

75 minutes should feel:

> fuller and more serious

without becoming:

> bloated or random.

---

#### 90 Minutes

##### Expected Feel

- advanced hypertrophy session
- large-muscle specialization
- meaningful fatigue layering

##### Expected Characteristics

- larger exercise counts
- more row/press environments
- higher specialization feel

##### Acceptable

- 1 vertical + 3 row structures on Pull
- multiple chest environments on Push
- advanced lower-body layering

##### Warnings

- same-environment clustering
- excessive press ecosystem overlap
- machine spam
- support-profile monotony

##### Philosophy

90-minute sessions may legitimately become:

- row-heavy on Pull
- chest-dense on Push
- highly layered on Legs

This is acceptable IF:

- support profiles differ
- loading environments differ
- fatigue textures differ

---

#### 105–120 Minutes

##### Expected Feel

- advanced/high-volume bodybuilding
- expanded specialization
- deep stimulus coverage

##### Expected Characteristics

- larger exercise pools
- expanded stimulus environments
- higher fatigue complexity
- greater support-profile diversity

##### Acceptable

- multiple row environments
- multiple chest environments
- expanded leg stimulus layering
- more advanced exercise combinations

##### Warnings

- random filler
- unrealistic junk volume
- excessive redundancy
- excessive spinal-loading overlap
- overinflated accessory work

##### Philosophy

Long sessions should feel:

> intelligently expanded

NOT:

> artificially inflated.

Additional exercises must still feel biomechanically justified.

---

### Experience-Level Advisory Philosophy

#### None / Beginner

##### Expected Characteristics

- stable equipment bias
- lower coordination demand
- lower spinal fatigue
- simpler exercise environments

##### Acceptable

- Smith Machine preference
- machine-supported rows
- machine pressing
- seated stability bias

##### Warnings

- excessive unsupported compounds
- advanced fatigue stacking
- overly technical exercise combinations
- highly unstable movement environments

##### Philosophy

Beginner programming should prioritize:

- confidence
- safety
- consistency
- progression comfort

NOT:

- maximal biomechanical sophistication.

---

#### Intermediate

##### Expected Characteristics

- balanced equipment exposure
- growing freeweight exposure
- moderate variation
- moderate fatigue complexity

##### Acceptable

- mixed freeweight/machine environments
- moderate support-profile diversity
- moderate spinal loading

##### Warnings

- excessive machine dependence
- excessive advanced specialization
- chaotic exercise environments

##### Philosophy

Intermediate should feel like:

> serious gym-goer progression.

---

#### Advanced

##### Expected Characteristics

- freeweight bias
- higher coordination demand
- larger stimulus diversity
- realistic bodybuilding complexity

##### Acceptable

- multiple row environments
- unsupported compounds
- advanced compound layering
- higher fatigue complexity
- more specialized Pull Days

##### Warnings

- machine overreliance
- excessive stability dependence
- loss of compound anchors
- overly simplistic programming

##### Philosophy

Advanced users should feel:

> intelligently challenged

without:

> artificial randomness.

---

### Recovery Advisory Philosophy

Recovery/readiness bubbles are:

- guidance
- training heuristics
- workload-aware estimates

They are NOT:

- medical recommendations
- exact physiological measurements
- HRV simulations

#### Expected Behavior

- heavy sessions recover slower
- light sessions recover faster
- lower body recovers slower than upper body
- bottleneck muscle determines readiness state

#### Acceptable

- advanced long-duration sessions remaining red longer
- Push/Upper overlap affecting chest/shoulder recovery
- cumulative weekly fatigue influence

#### Warnings

- negative recovery values
- over-100 recovery values
- recovery corruption across repeated split cards
- invalid bottleneck muscles

#### Philosophy

Recovery should feel:

> believable and coach-like

NOT:

> clinically overcomplicated.

---

### Audit Interpretation Philosophy

IMPORTANT:
A WARN or FAIL in audits does NOT automatically mean:

> bad workout.

Many audit warnings indicate:

- realism imperfections
- texture clustering
- non-optimal diversity
- advanced-bodybuilding overlap

NOT:

- structural corruption

#### True Structural Danger Signals

- slot integrity failures
- missing stimulus coverage
- cardIndex leakage
- replacement corruption
- history mutation
- invalid recovery values
- cross-card contamination

#### Soft Realism Warnings

Occasional warnings are acceptable for:

- row density
- support-profile overlap
- press clustering
- advanced specialization

#### Philosophy

Audits exist to:

> guide refinement

NOT:

> force mathematical perfection.

---

### Manual Review Philosophy

Human visual inspection remains critical.

The generator should ultimately be judged by:

> "Would this feel intelligently programmed to a real lifter?"

NOT solely by:

- audit counts
- similarity metrics
- ecosystem scores
- warning totals

The goal is:

- believable bodybuilding structure
- premium coaching feel
- sustainable variation
- intelligent fatigue flow
- psychologically satisfying workouts

NOT:

- maximal uniqueness at all costs.

---

### Long-Term Generator Philosophy

MaxHype is intentionally designed to evolve toward:

- premium coaching feel
- intelligent specialization
- believable fatigue flow
- realistic bodybuilding progression

Future improvements should increasingly focus on:

- emotional UX
- session feel
- weekly storytelling
- progression psychology
- premium mobile experience

NOT:

- endless generator rewrites
- excessive hard rules
- overfitted audit perfectionism

The generator is now considered:

> structurally mature.

Future work should remain:

- surgical
- additive
- realism-focused
- architecture-preserving

---

## Future Evolution Philosophy

The MaxHype generator is considered structurally mature.

Future development should prioritize:

- coaching quality
- workout feel
- realistic hypertrophy programming
- premium user experience
- long-term progression
- realism
- maintainability

Future development should avoid unnecessary architectural rewrites once stable systems have been validated.

The preferred philosophy is:

**Refine.**

**Do not reinvent.**

---

## Version 2.1 Clarifications

This revision introduces documentation clarifications only.

No generator methodology, ordering philosophy, or architectural behavior has changed.

The clarifications exist solely to reduce ambiguity for future implementations and Generator Bible compliance audits.
