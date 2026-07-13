import '../../models/exercise.dart';

/// Per-build mutable state for one workout generation.
///
/// The web prototype keeps this as module-level globals (`_currentBuildSplit`,
/// `_patternUsage`, `usedNames`, `usedMoveGroups`, `_currentBuildCompoundCount`,
/// `_firstPullPattern`, ...) that it resets at the top of `buildWorkoutForIndex`.
/// Encapsulating them here makes generation reentrant and testable — a fresh
/// [BuildState] per build, no cross-call leakage.
class BuildState {
  /// The split being built ("Push Day" / "Pull Day" / "Legs + Core").
  final String split;

  BuildState(this.split);

  /// Exercises committed so far, in slot order.
  final List<Exercise> exercises = [];

  /// Names already used this build (hard duplicate block).
  final Set<String> usedNames = {};

  /// Movement groups already used (diversity + dedup).
  final Set<String> usedMovementGroups = {};

  /// Categories already used (Legs diversity).
  final Set<String> usedCategories = {};

  /// Count of compound picks so far (primary vs later compound).
  int compoundCount = 0;

  /// Pull Day: the movement pattern of the first primary pull, used to force
  /// the second primary pull to alternate (horizontal <-> vertical).
  String? firstPullPattern;

  /// Movement-pattern bucket usage this build (pattern caps).
  final Map<String, int> patternUsage = {};

  /// Stimulus bucket usage this build (stimulus caps / soft penalties).
  final Map<String, int> stimulusUsage = {};

  /// slotType -> {exerciseName: count} in-workout anti-domination tracker.
  final Map<String, Map<String, int>> slotUsage = {};

  /// slotType -> total picks (denominator for anti-domination).
  final Map<String, int> slotTotals = {};

  bool isNameUsed(String name) => usedNames.contains(name);

  /// Records a committed pick against all trackers.
  void commit(Exercise exercise, {String? slotType, String? movementGroup}) {
    exercises.add(exercise);
    usedNames.add(exercise.name);
    final meta = exercise.generatorMeta;
    if (movementGroup != null) usedMovementGroups.add(movementGroup);
    if (meta?.category != null) usedCategories.add(meta!.category);
    if (slotType != null) {
      final byName = slotUsage.putIfAbsent(slotType, () => {});
      byName[exercise.name] = (byName[exercise.name] ?? 0) + 1;
      slotTotals[slotType] = (slotTotals[slotType] ?? 0) + 1;
    }
  }

  void bumpPattern(String bucket) =>
      patternUsage[bucket] = (patternUsage[bucket] ?? 0) + 1;

  void bumpStimulus(String bucket) =>
      stimulusUsage[bucket] = (stimulusUsage[bucket] ?? 0) + 1;
}
