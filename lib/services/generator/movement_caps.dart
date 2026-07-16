import '../../models/exercise.dart';

/// Movement-balancing caps ported from the web prototype's selection engine.
///
/// Three independent systems limit how much of one movement family a single
/// workout can stack. They differ in HOW they apply (faithful to script.js):
///
///   * [patternCaps]        — per-split, HARD cap + soft penalty (-10/use),
///                            with fallback relaxation when the pool empties.
///                            (script.js:3133 table, :9803 application)
///   * [stimulusCaps]       — per-split, SOFT penalty only (-12/use). The
///                            prototype disabled the hard cap here after it
///                            caused distribution regressions, so we don't
///                            hard-block on stimulus either.
///                            (script.js:3323 table, :9831 application)
///   * [movementGroupCaps]  — global super-group, HARD exclusion at the
///                            pool-building stage (before scoring).
///                            (script.js:1964 table, :8239 application)
///
/// The pattern/stimulus BUCKET a candidate falls into is derived by
/// split-specific routing over its metadata (movementPattern / primaryMuscle /
/// stimulusType) — see [MovementCaps.patternBucketOf] / [stimulusBucketOf].
/// The movement-group super-group is a flat name→group→super-group lookup.
class MovementCaps {
  const MovementCaps();

  /// Soft-penalty magnitude per existing use in a partially-filled pattern
  /// bucket (script.js:9825 `_s -= _pcCount * 10`).
  static const double patternSoftPenaltyPerUse = 10;

  /// Soft-penalty magnitude per existing use in a stimulus bucket
  /// (script.js:9839 `_s -= _stCount * 12`).
  static const double stimulusSoftPenaltyPerUse = 12;

  /// PATTERN_CAPS (script.js:3133). split → bucket → max occurrences.
  static const Map<String, Map<String, int>> patternCaps = {
    'Pull Day': {
      'horizontal_row': 2,
      'vertical_pull': 2,
      'rear_delt': 1,
      'biceps_curl': 2,
      'support': 1,
    },
    'Push Day': {
      'flat_press': 1,
      'incline_press': 1,
      'decline_press': 1,
      'chest_fly': 1,
      'shoulder_press': 1,
      'lateral_raise': 2,
      'front_raise': 1,
      'triceps': 2,
    },
    'Legs + Core': {
      'squat_lunge': 2,
      'hinge': 2,
      'hamstring_curl': 1,
      'quad_iso': 1,
      'glute_accessory': 1,
      'calf': 1,
      'core': 2,
    },
  };

  /// STIMULUS_CAPS (script.js:3323). split → bucket → max (soft only).
  static const Map<String, Map<String, int>> stimulusCaps = {
    'Pull Day': {
      'back_thickness': 2,
      'back_width': 2,
      'rear_delt': 1,
      'biceps': 2,
      'support': 1,
    },
    'Push Day': {
      'chest': 2,
      'shoulders': 2,
      'triceps': 2,
    },
    'Legs + Core': {
      'quad_compound': 2,
      'hinge': 2,
      'hamstring_iso': 1,
      'quad_iso': 1,
      'glute_accessory': 1,
      'calves': 1,
      'core': 2,
    },
  };

  /// MOVEMENT_GROUP_CAPS (script.js:1964). Global super-group → max. Applied as
  /// a HARD exclusion before scoring.
  static const Map<String, int> movementGroupCaps = {
    'chest_press': 2,
    'shoulder_press': 1,
    'lateral_raise': 1,
    'front_raise': 1,
    'chest_fly': 2,
    'hip_thrust': 1,
    'lat_pulldown_machine': 1,
    'pullup_chinup_family': 1,
  };

  /// `MOVEMENT_SUPER_GROUPS` (script.js:1939). movementGroup → super-group.
  /// Only the eight super-groups in [movementGroupCaps] are capped; every other
  /// group maps to null (uncapped).
  static const Map<String, String> movementSuperGroups = {
    'flat_press': 'chest_press',
    'incline_press': 'chest_press',
    'decline_press': 'chest_press',
    'shoulder_press': 'shoulder_press',
    'db_lateral_raise': 'lateral_raise',
    'cable_lateral_raise': 'lateral_raise',
    'machine_lateral_raise': 'lateral_raise',
    'cable_fly': 'chest_fly',
    'db_fly': 'chest_fly',
    'machine_fly': 'chest_fly',
    'hip_thrust': 'hip_thrust',
    'front_raise': 'front_raise',
    'pulldown': 'lat_pulldown_machine',
    'assisted_pullup': 'pullup_chinup_family',
    'assisted_wide_pullup': 'pullup_chinup_family',
    'chin_ups': 'pullup_chinup_family',
  };

  /// Chest-press pattern buckets that are NEVER flushed back even when the pool
  /// empties (per-angle uniqueness is a hard invariant — script.js:9887).
  static const Set<String> chestPressAngleBuckets = {
    'flat_press',
    'incline_press',
    'decline_press',
  };

  /// The super-group of [ex] for MOVEMENT_GROUP_CAPS, or null if uncapped.
  String? movementSuperGroupOf(Exercise ex) {
    final mg = ex.generatorMeta?.movementGroup;
    if (mg == null) return null;
    return movementSuperGroups[mg];
  }

  /// Whether committing [candidate] would keep its movement super-group within
  /// its hard cap (script.js `isMovementGroupCapAllowed`). The prototype's
  /// dynamic relaxation only fires for focus-mode muscle preferences, which
  /// this app has no data source for (no focus labels in FitnessPlan), so the
  /// base cap always applies — the dynamic path is a faithful no-op here.
  bool isMovementGroupCapAllowed(
    List<Exercise> committed,
    Exercise candidate,
  ) {
    final sg = movementSuperGroupOf(candidate);
    if (sg == null) return true;
    final cap = movementGroupCaps[sg];
    if (cap == null) return true;
    var count = 0;
    for (final e in committed) {
      if (movementSuperGroupOf(e) == sg) count++;
    }
    return count < cap;
  }

  /// `_patternBucketFor` (script.js:3186). Split-specific routing over the
  /// candidate's movementPattern (`p`) and primaryMuscle (`pm`). Returns null
  /// when the exercise doesn't fall into any capped bucket for [split].
  ///
  /// Ported to this app's metadata vocabulary (the extractor emits a few tokens
  /// that differ from the prototype's EXERCISE_QUALITY_META — the mapping keeps
  /// the SAME bucket semantics): shoulder press uses `vertical_press`, rear
  /// delt uses primaryMuscle `rear_delt`, quad isolation uses `knee_extension`,
  /// hamstring uses `knee_flexion`.
  String? patternBucketOf(Exercise ex, String split) {
    final meta = ex.generatorMeta;
    if (meta == null) return null;
    final p = meta.movementPattern ?? '';
    final pm = meta.primaryMuscle ?? '';
    final st = meta.stimulusType ?? '';

    switch (split) {
      case 'Push Day':
        if (pm == 'chest' && p == 'flat_press') return 'flat_press';
        if (pm == 'chest' && p == 'incline_press') return 'incline_press';
        if (pm == 'chest' && p == 'decline_press') return 'decline_press';
        if (p == 'chest_fly') return 'chest_fly';
        if (pm == 'shoulders' && p == 'vertical_press') return 'shoulder_press';
        if (p == 'lateral_raise') return 'lateral_raise';
        if (p == 'front_raise') return 'front_raise';
        if (pm == 'triceps') return 'triceps';
        return null;
      case 'Pull Day':
        if (p == 'horizontal_row' || p == 'supported_row') {
          return 'horizontal_row';
        }
        if (p == 'vertical_pull') return 'vertical_pull';
        if (p == 'rear_delt_fly' || pm == 'rear_delt') return 'rear_delt';
        if (pm == 'biceps') return 'biceps_curl';
        if (pm == 'traps' || p == 'shrug') return 'support';
        return null;
      case 'Legs + Core':
        if (p == 'squat' || p == 'leg_press' || p == 'lunge') {
          return 'squat_lunge';
        }
        if (p == 'hinge') return 'hinge';
        if (p == 'knee_flexion' || p == 'hamstring_curl') {
          return 'hamstring_curl';
        }
        if (pm == 'quads' &&
            (p == 'knee_extension' || st == 'shortened_biased')) {
          return 'quad_iso';
        }
        if (pm == 'glutes') return 'glute_accessory';
        if (pm == 'calves') return 'calf';
        if (pm == 'abs' || pm == 'obliques' || pm == 'core') return 'core';
        return null;
      default:
        return null;
    }
  }

  /// `_stimulusBucketFor` (script.js:3346). Same vocabulary adjustments as
  /// [patternBucketOf].
  String? stimulusBucketOf(Exercise ex, String split) {
    final meta = ex.generatorMeta;
    if (meta == null) return null;
    final p = meta.movementPattern ?? '';
    final pm = meta.primaryMuscle ?? '';
    final st = meta.stimulusType ?? '';

    switch (split) {
      case 'Pull Day':
        if (p == 'horizontal_row' || p == 'supported_row') {
          return 'back_thickness';
        }
        if (p == 'vertical_pull') return 'back_width';
        if (p == 'rear_delt_fly' || pm == 'rear_delt') return 'rear_delt';
        if (pm == 'biceps') return 'biceps';
        if (pm == 'traps' || p == 'shrug') return 'support';
        return null;
      case 'Push Day':
        if (pm == 'chest') return 'chest';
        if (pm == 'shoulders') return 'shoulders';
        if (pm == 'triceps') return 'triceps';
        return null;
      case 'Legs + Core':
        if (pm == 'quads' &&
            (p == 'squat' || p == 'leg_press' || p == 'lunge')) {
          return 'quad_compound';
        }
        if (p == 'hinge') return 'hinge';
        if (p == 'knee_flexion' || p == 'hamstring_curl') {
          return 'hamstring_iso';
        }
        if (pm == 'quads' &&
            (p == 'knee_extension' || st == 'shortened_biased')) {
          return 'quad_iso';
        }
        if (pm == 'glutes') return 'glute_accessory';
        if (pm == 'calves') return 'calves';
        if (pm == 'abs' || pm == 'obliques' || pm == 'core') return 'core';
        return null;
      default:
        return null;
    }
  }

  /// True if committing [candidate] would exceed its pattern-cap bucket for
  /// [split] (a HARD cap, subject to fallback relaxation — except chest-press
  /// angles). [patternUsage] is the current per-bucket count.
  bool patternCapHit(
    Exercise candidate,
    String split,
    Map<String, int> patternUsage,
  ) {
    final bucket = patternBucketOf(candidate, split);
    if (bucket == null) return false;
    final cap = patternCaps[split]?[bucket];
    if (cap == null) return false;
    return (patternUsage[bucket] ?? 0) >= cap;
  }
}
