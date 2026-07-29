import 'dart:async';

import '../core/demo_clock.dart';
import '../core/weight_units.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/monthly_data.dart';
import '../models/all_time_stats.dart';
import '../models/generator/fitness_plan.dart';
import '../models/generator/rotation_memory.dart';
import '../models/workout_completion.dart';
import '../data/mock_data.dart';
import '../services/generator/workout_assembler.dart';
import 'fitness_plan_repository.dart';
import 'rotation_memory_repository.dart';
import 'workout_repository.dart';

/// [WorkoutRepository] backed by the PPL generator.
///
/// Replaces [MockWorkoutRepository] as the source of the home cards: it reads
/// the persisted [FitnessPlan] and generates the card set from it, rather than
/// returning a hand-curated catalog. All other consumers (home, detail,
/// session, logging, completion, Replace) are unchanged — they still call
/// [getWorkouts] and receive [Workout]s.
///
/// Generated cards are cached in memory for the session so that:
/// - Card identity is stable (one active workout / workout-instance identity).
/// - A Replace mutation persists across subsequent reads (as with the mock).
///
/// The generation seed is derived deterministically from the plan, so the same
/// plan always yields the same cards (stable identity across restarts) while a
/// plan change yields a fresh set. [regenerate] rebuilds after a plan edit.
///
/// Cards are also regenerated when the ISO week changes, so a new week reflects
/// cross-session rotation memory (which dedups completions per week) without a
/// manual plan save — matching how the completed-this-week lock resets. The
/// week rebuild is suppressed while a session is active so a live workout's
/// exercises never change under the user (preserves workout identity and the
/// one-active-workout rule); it happens on the next read after the session
/// finishes.
///
/// Monthly data and all-time stats remain mock — they're a stats-display
/// concern outside the generator's scope for Part 2A.
class GeneratedWorkoutRepository implements WorkoutRepository {
  final FitnessPlanRepository _planRepository;
  final WorkoutAssembler _assembler;
  final RotationMemoryRepository? _rotationMemoryRepository;
  final WeekClock _weekClock;
  final Future<bool> Function()? _hasActiveSession;

  GeneratedWorkoutRepository({
    required FitnessPlanRepository planRepository,
    required WorkoutAssembler assembler,
    RotationMemoryRepository? rotationMemoryRepository,
    WeekClock? weekClock,
    Future<bool> Function()? hasActiveSession,
  }) : _planRepository = planRepository,
       _assembler = assembler,
       _rotationMemoryRepository = rotationMemoryRepository,
       _weekClock = weekClock ?? const RealWeekClock(),
       _hasActiveSession = hasActiveSession;

  List<Workout>? _workouts;
  FitnessPlan? _generatedFor;

  /// ISO (year, week) the cached cards were generated for, so a week rollover
  /// triggers a rebuild. Null until the first generation.
  ({int year, int week})? _generatedWeek;

  /// Per-card Regenerate bump counts (card index → count). Folded into that
  /// card's seed so each press re-rolls a different — but session-stable —
  /// selection. In-memory like the Replace mutation: any full rebuild (plan
  /// edit, Regenerate-all, week rollover) resets them.
  final Map<int, int> _cardRegenerations = {};

  /// Broadcast controller for the reactive [watchWorkouts] view. Broadcast so
  /// multiple listeners (and re-listens) are fine; the latest list is replayed
  /// to new listeners via [watchWorkouts] below.
  final _controller = StreamController<List<Workout>>.broadcast();

  @override
  Stream<List<Workout>> watchWorkouts() async* {
    // Replay the current list to a new subscriber, generating on first use,
    // then follow live updates.
    yield List<Workout>.unmodifiable(await _ensureGenerated());
    yield* _controller.stream;
  }

  /// Updates the cache and notifies stream listeners.
  void _setWorkouts(List<Workout> workouts) {
    _workouts = workouts;
    if (!_controller.isClosed) {
      _controller.add(List<Workout>.unmodifiable(workouts));
    }
  }

  Future<List<Workout>> _ensureGenerated() async {
    final plan = await _planRepository.load();
    if (await _shouldRegenerate(plan)) {
      final rotation =
          await _rotationMemoryRepository?.load() ??
          const RotationMemory.empty();
      _cardRegenerations.clear();
      _setWorkouts(
        _assembler.buildCards(
          plan,
          seedBase: _seedForPlan(plan),
          rotationMemory: rotation,
        ),
      );
      _generatedFor = plan;
      _generatedWeek = isoWeekOf(_weekClock.now());
    }
    return _workouts!;
  }

  /// Whether the cached cards are stale and need rebuilding:
  /// - never generated, or
  /// - the plan changed since last time, or
  /// - the ISO week rolled over — but only if no session is active, so a live
  ///   workout's exercises are never swapped out from under the user. The week
  ///   rebuild then happens on the next read after the session ends.
  Future<bool> _shouldRegenerate(FitnessPlan plan) async {
    if (_workouts == null || !_samePlan(_generatedFor, plan)) return true;
    final currentWeek = isoWeekOf(_weekClock.now());
    if (_generatedWeek != null &&
        (currentWeek.year != _generatedWeek!.year ||
            currentWeek.week != _generatedWeek!.week)) {
      final active = await _hasActiveSession?.call() ?? false;
      return !active;
    }
    return false;
  }

  /// Forces a rebuild from the latest persisted plan (call after a plan edit).
  /// Emits the new list on [watchWorkouts].
  Future<List<Workout>> regenerate() async {
    _workouts = null;
    _generatedFor = null;
    _generatedWeek = null;
    return _ensureGenerated();
  }

  /// Releases the stream controller. Call when the repository is disposed.
  void dispose() => _controller.close();

  @override
  Future<List<Workout>> getWorkouts() async {
    final workouts = await _ensureGenerated();
    return List<Workout>.unmodifiable(workouts);
  }

  @override
  Future<List<MonthlyData>> getMonthlyData() async =>
      // Convert mock volume (pounds) to the user's chosen unit at this data
      // boundary so chart views stay unit-agnostic.
      _planRepository.units.value.convertMonthly(MockData.getMonthlyData());

  @override
  Future<AllTimeStats> getAllTimeStats() async =>
      _planRepository.units.value.convertStats(MockData.getAllTimeStats());

  /// Re-rolls a single card: same id/identity (split + index), fresh exercise
  /// selection under a bumped per-card seed. Other cards are untouched, and
  /// the change is broadcast on [watchWorkouts] like a Replace mutation.
  ///
  /// Guarded against a live session (the UI hides the control during one, but
  /// the identity/one-active-workout rules must hold regardless): a no-op
  /// while any session is active.
  @override
  Future<void> regenerateWorkout(String workoutId) async {
    if (await _hasActiveSession?.call() ?? false) return;
    final workouts = List<Workout>.of(await _ensureGenerated());
    final idx = workouts.indexWhere((w) => w.id == workoutId);
    if (idx < 0) return;

    final plan = await _planRepository.load();
    final rotation =
        await _rotationMemoryRepository?.load() ?? const RotationMemory.empty();
    final bump = (_cardRegenerations[idx] ?? 0) + 1;
    _cardRegenerations[idx] = bump;
    workouts[idx] = _assembler.buildCard(
      plan,
      index: idx,
      // Offset the plan seed by a large odd stride per bump so successive
      // presses walk distinct seeds without colliding with sibling cards'
      // `seedBase + index` offsets.
      seedBase: _seedForPlan(plan) + bump * 1000003,
      rotationMemory: rotation,
    );
    _setWorkouts(workouts);
  }

  /// In-place swap by design: the replacement takes the old exercise's slot
  /// and no other exercise moves. Generator ordering rules apply only at
  /// generation time — replacement intentionally never re-runs the ordering
  /// pass, even when the swap crosses phases (e.g. Leg Press → Leg
  /// Extension), per the Generator Bible §Replacement System → Ordering
  /// Preservation (docs/generator/MAXHYPE_GENERATOR_BIBLE_V2.md).
  @override
  Future<void> replaceExercise({
    required String workoutId,
    required String oldExerciseId,
    required Exercise newExercise,
  }) async {
    final workouts = List<Workout>.of(await _ensureGenerated());
    final idx = workouts.indexWhere((w) => w.id == workoutId);
    if (idx < 0) return;
    final w = workouts[idx];
    final exIdx = w.exercises.indexWhere((e) => e.id == oldExerciseId);
    if (exIdx < 0) return;

    final newExercises = List<Exercise>.of(w.exercises);
    newExercises[exIdx] = newExercise;
    workouts[idx] = Workout(
      id: w.id,
      title: w.title,
      subtitle: w.subtitle,
      duration: w.duration,
      exerciseCount: newExercises.length,
      exercises: newExercises,
      targetMuscles: w.targetMuscles,
      recoveryInfo: w.recoveryInfo,
    );
    // Emit the mutated list so the home carousel reflects the swap too.
    _setWorkouts(workouts);
  }

  bool _samePlan(FitnessPlan? a, FitnessPlan b) {
    if (a == null) return false;
    return a.split == b.split &&
        a.daysPerWeek == b.daysPerWeek &&
        a.durationMinutes == b.durationMinutes &&
        a.experience == b.experience &&
        // A Regenerate bump changes only this field, but must still rebuild.
        a.generation == b.generation;
  }

  /// Deterministic seed from the plan fields that shape generation, so the same
  /// plan reproduces the same cards. Uses a simple stable string hash (Dart's
  /// String.hashCode is not stable across runs, so we compute our own). The
  /// [FitnessPlan.generation] counter is folded in so a Regenerate action
  /// yields a different — but still reproducible — set for the same settings.
  ///
  /// The current ISO week is folded in too, so every newly generated weekly
  /// plan receives a new seed: a week rollover produces fresh workouts even
  /// with no completions, while cards stay stable (reproducible) within the
  /// week. This mirrors the prototype's spirit — it regenerates with fresh
  /// randomness on every rebuild — without giving up within-week determinism.
  int _seedForPlan(FitnessPlan plan) {
    final week = isoWeekOf(_weekClock.now());
    final key =
        '${plan.split.wireValue}|${plan.daysPerWeek}'
        '|${plan.durationMinutes}|${plan.experience.wireValue}'
        '|${plan.generation}|${week.year}-${week.week}';
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
