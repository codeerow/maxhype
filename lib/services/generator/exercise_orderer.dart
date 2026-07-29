import 'package:collection/collection.dart' show mergeSort;

import '../../models/exercise.dart';
import '../../models/generator/exercise_taxonomy.dart';

/// The prototype's final exercise-ordering pass (`orderWorkoutExercises`,
/// script.js:5804-5980) — the "FINAL ORDERING PASS: enforce strict structure
/// regardless of generation order" applied to every generated workout.
///
/// Slot plans are NOT authored in bodybuilding order (e.g. the Push 90+ plans
/// place a chest compound in the last slot, after isolations and triceps), so
/// this pass is what puts compounds ahead of isolation work:
///
/// * **Push Day** — hard role buckets rebuilt in order: chest compounds →
///   chest isolation → shoulder compounds → shoulder isolation → triceps →
///   other. Within buckets: chest/shoulder by section priority; shoulder
///   isolation by equipment order (dumbbell → machine → cable, then
///   alphabetical); triceps by movement-group family (compound → overhead →
///   skullcrusher → pushdown → kickback), compounds first within a family.
/// * **Pull Day** — group blocks `upper_back → lats → rear_delt → biceps →
///   support` (unknown groups last); within a block compounds first, then
///   section priority.
/// * **Legs + Core** — phase-based movement ordering (the prototype's final
///   `_enforceLegsPhaseOrdering` pass, script.js:4343, applied at the very
///   end of `buildWorkoutForIndex` ON TOP of the group-block pass): squat /
///   leg-press / lunge patterns → hinge / hip-thrust patterns → leg
///   isolations → calves → core (always last). The group-block pass still
///   runs first, so within a phase the relative order (compounds first,
///   quad isolations before hamstring before glute) matches the executed
///   prototype exactly.
///
/// All sorts are stable (the prototype relies on JS's stable `Array.sort` to
/// preserve generation order on ties, so we use [mergeSort] — Dart's
/// `List.sort` is not stable).
class ExerciseOrderer {
  const ExerciseOrderer();

  /// `SECTION_PRIORITY` (script.js:5599). Category → intra-section rank;
  /// unknown categories rank 99.
  static const Map<String, Map<String, int>> _sectionPriority = {
    'Push Day': {
      'chest press': 0,
      'incline press': 1,
      'decline press': 2,
      'shoulder press': 3,
      'compound press': 4,
      'chest fly': 5,
      'front delt': 6,
      'side delt': 7,
      'triceps': 8,
    },
    'Pull Day': {
      'row': 0,
      'pulldown': 1,
      'rear delt': 2,
      'shrug': 3,
      'biceps': 4,
      'forearms': 5,
      'upright row': 6,
    },
    'Legs + Core': {
      'abs': 0,
      'core accessory': 1,
      'squat': 2,
      'hinge': 3,
      'hip thrust': 4,
      'lunge': 5,
      'quad': 6,
      'hamstring curl': 7,
      'calf raise': 8,
      'hip abduction': 9,
      'hip adduction': 10,
    },
  };

  /// `SECTION_GROUPS` (script.js:5616). Category → body-section group;
  /// unknown categories map to "other".
  static const Map<String, Map<String, String>> _sectionGroups = {
    'Push Day': {
      'chest press': 'chest',
      'incline press': 'chest',
      'decline press': 'chest',
      'chest fly': 'chest',
      'shoulder press': 'shoulders',
      'front delt': 'shoulders',
      'side delt': 'shoulders',
      'compound press': 'triceps',
      'triceps': 'triceps',
    },
    'Pull Day': {
      'row': 'upper_back',
      'pulldown': 'lats',
      'biceps': 'biceps',
      'upright row': 'upper_back',
      'rear delt': 'rear_delt',
      'shrug': 'support',
      'forearms': 'support',
    },
    'Legs + Core': {
      'squat': 'quads',
      'quad': 'quads',
      'lunge': 'quads',
      'hinge': 'hamstrings',
      'hamstring curl': 'hamstrings',
      'hip thrust': 'glutes',
      'kickback': 'glutes',
      'calf raise': 'calves',
      'abs': 'core',
      'core accessory': 'core',
      'back extension': 'core',
      'hip abduction': 'accessories',
      'hip adduction': 'accessories',
    },
  };

  /// Lateral-raise equipment order for the Push shoulder-isolation bucket
  /// (script.js:5859): dumbbell → machine → cable, anything else last.
  static const Map<String, int> _lateralEquipmentOrder = {
    'dumbbell': 0,
    'machine': 1,
    'cable': 2,
  };

  /// Triceps movement-group family order (script.js:5886); unknown families
  /// rank with pushdowns (3), exactly as the prototype.
  static const Map<String, int> _tricepsGroupOrder = {
    'tri_compound': 0,
    'tri_overhead': 1,
    'skullcrusher': 2,
    'tri_pushdown': 3,
    'tri_kickback': 4,
  };

  static const List<String> _pullGroupOrder = [
    'upper_back',
    'lats',
    'rear_delt',
    'biceps',
    'support',
  ];

  static const List<String> _legsGroupOrder = [
    'quads',
    'hamstrings',
    'glutes',
    'calves',
    'accessories',
    'core',
  ];

  /// Returns [exercises] rebuilt in the split's canonical bodybuilding order.
  /// Pure — the input list is not mutated.
  List<Exercise> order(String split, List<Exercise> exercises) {
    switch (split) {
      case 'Push Day':
        return _orderPush(exercises);
      case 'Pull Day':
        return _orderBlocks(exercises, 'Pull Day', _pullGroupOrder);
      case 'Legs + Core':
        // Two passes, exactly like the executed prototype: the group-block
        // pass establishes within-phase relative order, then the stable
        // phase pass regroups by movement phase.
        return _legsPhaseReorder(
          _orderBlocks(exercises, 'Legs + Core', _legsGroupOrder),
        );
      default:
        return List.of(exercises);
    }
  }

  /// The Legs movement phase for an exercise (prototype `_legsPhaseFor`,
  /// script.js:4307). Metadata-driven, checked in the prototype's exact rule
  /// order:
  ///
  /// 1. squat / leg-press / lunge patterns
  /// 2. hinge / hip-thrust patterns (plus any hamstring/glute compound)
  /// 3. leg isolations (leg extensions, leg curls, kickbacks, ab/adduction,
  ///    and any remaining quads/hamstrings/glutes accessory)
  /// 4. calves
  /// 5. core (abs / obliques / lower back) — always last
  ///
  /// Unclassifiable exercises (no metadata) return 99 and are placed before
  /// core, honoring the "core must always remain last" rule.
  static int legsPhaseFor(Exercise e) {
    final meta = e.generatorMeta;
    if (meta == null) return 99;
    final pm = meta.primaryMuscle ?? '';
    final mp = meta.movementPattern ?? '';
    final role = meta.hypertrophyRole ?? '';
    final isCompound =
        role == 'primary_compound' || role == 'secondary_compound';

    // Phase 5 — core / abs / obliques / lower back. Always last.
    if (pm == 'abs' || pm == 'obliques' || pm == 'core' || pm == 'lower_back') {
      return 5;
    }
    // Phase 4 — calves.
    if (pm == 'calves') return 4;
    // Phase 1 — primary leg compounds via pattern.
    if (mp == 'squat' || mp == 'leg_press' || mp == 'lunge') return 1;
    // Phase 2 — posterior chain compounds via pattern.
    if (mp == 'hinge' || mp == 'hip_thrust') return 2;
    // Remaining big-leg compounds route to the matching compound phase.
    if (isCompound) {
      if (pm == 'hamstrings' || pm == 'glutes') return 2;
      if (pm == 'quads') return 1;
    }
    // Phase 3 — leg isolation / accessory.
    if (pm == 'quads' || pm == 'hamstrings' || pm == 'glutes') return 3;
    // Pattern fallback: the prototype's names plus this library's wire
    // synonyms (knee_extension/knee_flexion for extensions/curls).
    if (mp == 'leg_extension' ||
        mp == 'knee_extension' ||
        mp == 'hamstring_curl' ||
        mp == 'knee_flexion' ||
        mp == 'kickback' ||
        mp == 'abduction' ||
        mp == 'adduction') {
      return 3;
    }
    return 99;
  }

  /// Stable phase regroup (prototype `_enforceLegsPhaseOrdering`,
  /// script.js:4343): concat phase buckets in order, preserving the incoming
  /// relative order within each. One deliberate spec deviation, per the
  /// customer's decision: unclassifiable (99) exercises land BEFORE core so
  /// that core is always last (the prototype appends them after core, but no
  /// generated exercise is ever unclassifiable — the branch exists only for
  /// safety).
  List<Exercise> _legsPhaseReorder(List<Exercise> exercises) {
    final phases = {
      for (final p in const [1, 2, 3, 4, 99, 5]) p: <Exercise>[],
    };
    for (final e in exercises) {
      phases[legsPhaseFor(e)]!.add(e);
    }
    return [
      for (final p in const [1, 2, 3, 4, 99, 5]) ...phases[p]!,
    ];
  }

  bool _isCompound(Exercise e) =>
      e.generatorMeta?.type == ExerciseType.compound;

  String _groupOf(String split, Exercise e) =>
      _sectionGroups[split]?[e.generatorMeta?.category] ?? 'other';

  int _priorityOf(String split, Exercise e) =>
      _sectionPriority[split]?[e.generatorMeta?.category] ?? 99;

  List<Exercise> _orderPush(List<Exercise> exercises) {
    final chestCompounds = <Exercise>[];
    final shoulderCompounds = <Exercise>[];
    final chestIso = <Exercise>[];
    final shoulderIso = <Exercise>[];
    final triceps = <Exercise>[];
    final other = <Exercise>[];

    for (final e in exercises) {
      final g = _groupOf('Push Day', e);
      if (g == 'triceps') {
        triceps.add(e); // compounds and isolation both live in the tri block
      } else if (_isCompound(e)) {
        switch (g) {
          case 'chest':
            chestCompounds.add(e);
          case 'shoulders':
            shoulderCompounds.add(e);
          default:
            other.add(e);
        }
      } else {
        switch (g) {
          case 'chest':
            chestIso.add(e);
          case 'shoulders':
            shoulderIso.add(e);
          default:
            other.add(e);
        }
      }
    }

    int byPriority(Exercise a, Exercise b) =>
        _priorityOf('Push Day', a) - _priorityOf('Push Day', b);
    mergeSort(chestCompounds, compare: byPriority);
    mergeSort(chestIso, compare: byPriority);
    mergeSort(shoulderCompounds, compare: byPriority);

    // Shoulder isolation: equipment order, alphabetical tiebreak
    // (script.js:5859-5869).
    mergeSort(
      shoulderIso,
      compare: (a, b) {
        final aOrd =
            _lateralEquipmentOrder[(a.generatorMeta?.equipment.label ?? '')
                .toLowerCase()
                .trim()] ??
            9;
        final bOrd =
            _lateralEquipmentOrder[(b.generatorMeta?.equipment.label ?? '')
                .toLowerCase()
                .trim()] ??
            9;
        if (aOrd != bOrd) return aOrd - bOrd;
        return a.name.compareTo(b.name);
      },
    );

    // Triceps: family order, compounds before isolation within a family
    // (script.js:5885-5898).
    mergeSort(
      triceps,
      compare: (a, b) {
        final aOrd = _tricepsGroupOrder[a.generatorMeta?.movementGroup] ?? 3;
        final bOrd = _tricepsGroupOrder[b.generatorMeta?.movementGroup] ?? 3;
        if (aOrd != bOrd) return aOrd - bOrd;
        final aC = _isCompound(a);
        final bC = _isCompound(b);
        if (aC && !bC) return -1;
        if (!aC && bC) return 1;
        return 0;
      },
    );

    return [
      ...chestCompounds,
      ...chestIso,
      ...shoulderCompounds,
      ...shoulderIso,
      ...triceps,
      ...other,
    ];
  }

  /// Pull/Legs block strategy: bucket by section group in [groupOrder], sort
  /// each block compounds-first then section priority, append unknown-group
  /// exercises last (script.js:5919-5972).
  List<Exercise> _orderBlocks(
    List<Exercise> exercises,
    String split,
    List<String> groupOrder,
  ) {
    final blocks = {for (final g in groupOrder) g: <Exercise>[]};
    final other = <Exercise>[];
    for (final e in exercises) {
      (blocks[_groupOf(split, e)] ?? other).add(e);
    }

    int blockSort(Exercise a, Exercise b) {
      final aC = _isCompound(a);
      final bC = _isCompound(b);
      if (aC && !bC) return -1;
      if (!aC && bC) return 1;
      return _priorityOf(split, a) - _priorityOf(split, b);
    }

    for (final block in blocks.values) {
      mergeSort(block, compare: blockSort);
    }
    mergeSort(other, compare: blockSort);

    return [
      for (final g in groupOrder) ...blocks[g]!,
      ...other,
    ];
  }
}
