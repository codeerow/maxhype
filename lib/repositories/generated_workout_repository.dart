import 'dart:async';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/monthly_data.dart';
import '../models/all_time_stats.dart';
import '../models/generator/fitness_plan.dart';
import '../models/generator/rotation_memory.dart';
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
/// Monthly data and all-time stats remain mock — they're a stats-display
/// concern outside the generator's scope for Part 2A.
class GeneratedWorkoutRepository implements WorkoutRepository {
  final FitnessPlanRepository _planRepository;
  final WorkoutAssembler _assembler;
  final RotationMemoryRepository? _rotationMemoryRepository;

  GeneratedWorkoutRepository({
    required FitnessPlanRepository planRepository,
    required WorkoutAssembler assembler,
    RotationMemoryRepository? rotationMemoryRepository,
  }) : _planRepository = planRepository,
       _assembler = assembler,
       _rotationMemoryRepository = rotationMemoryRepository;

  List<Workout>? _workouts;
  FitnessPlan? _generatedFor;

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
    // Regenerate if never generated, or if the plan changed since last time.
    if (_workouts == null || !_samePlan(_generatedFor, plan)) {
      final rotation = await _rotationMemoryRepository?.load() ??
          const RotationMemory.empty();
      _setWorkouts(_assembler.buildCards(
        plan,
        seedBase: _seedForPlan(plan),
        rotationMemory: rotation,
      ));
      _generatedFor = plan;
    }
    return _workouts!;
  }

  /// Forces a rebuild from the latest persisted plan (call after a plan edit).
  /// Emits the new list on [watchWorkouts].
  Future<List<Workout>> regenerate() async {
    _workouts = null;
    _generatedFor = null;
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
  Future<List<MonthlyData>> getMonthlyData() async => MockData.getMonthlyData();

  @override
  Future<AllTimeStats> getAllTimeStats() async => MockData.getAllTimeStats();

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
        a.experience == b.experience;
  }

  /// Deterministic seed from the plan fields that shape generation, so the same
  /// plan reproduces the same cards. Uses a simple stable string hash (Dart's
  /// String.hashCode is not stable across runs, so we compute our own).
  int _seedForPlan(FitnessPlan plan) {
    final key =
        '${plan.split.wireValue}|${plan.daysPerWeek}'
        '|${plan.durationMinutes}|${plan.experience.wireValue}';
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
