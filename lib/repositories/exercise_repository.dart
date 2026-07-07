import '../models/exercise.dart';
import '../models/muscle_group.dart';
import '../models/generator/experience_level.dart';
import '../models/generator/exercise_taxonomy.dart';
import '../models/generator/duration_profile.dart';

abstract class ExerciseRepository {
  /// Get all exercises
  List<Exercise> getAllExercises();

  /// Get exercises filtered by muscle group
  List<Exercise> getExercisesByMuscleGroup(MuscleGroup muscleGroup);

  /// Get top N exercises by rating for a specific muscle group
  List<Exercise> getTopExercisesByMuscleGroup(
    MuscleGroup muscleGroup, {
    int limit = 8,
  });

  /// Get exercise by ID
  Exercise? getExerciseById(String id);

  // --- Generator queries (Part 1 foundation) --------------------------------

  /// Exercises whose generator category matches [category].
  List<Exercise> getExercisesByCategory(String category);

  /// Exercises at the given selection [tier] (A/B/C).
  List<Exercise> getExercisesByTier(ExerciseTier tier);

  /// Exercises eligible for automatic generation at [level]
  /// (respects minExperience, replaceOnly, generatorExclude).
  List<Exercise> getGeneratableExercises(ExperienceLevel level);

  /// Parsed generator metadata tables (duration profiles, set limits, tiers),
  /// or null for repositories without a generator library loaded.
  GeneratorMetadataTables? get metadataTables;

  /// One-time async load hook (reads the JSON asset). No-op by default.
  Future<void> load();
}

/// Default (no-op / empty) implementations of the generator queries, for
/// repositories that carry no generator metadata — e.g. the hand-curated
/// [MockExerciseRepository] behind the current home workouts. Keeps the
/// generator additions from forcing changes on those repositories.
mixin NoGeneratorMetadata on ExerciseRepository {
  @override
  List<Exercise> getExercisesByCategory(String category) => const [];

  @override
  List<Exercise> getExercisesByTier(ExerciseTier tier) => const [];

  @override
  List<Exercise> getGeneratableExercises(ExperienceLevel level) => const [];

  @override
  GeneratorMetadataTables? get metadataTables => null;

  @override
  Future<void> load() async {}
}
