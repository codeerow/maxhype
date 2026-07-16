import '../models/exercise.dart';
import '../models/generator/rotation_memory.dart';

/// Persists cross-session [RotationMemory] and records completed workouts into
/// it. Backed by [LocalRotationMemoryRepository] in production.
///
/// The generator reads a [RotationMemory] snapshot (via [load]) as pure input;
/// writes happen only when a workout is COMPLETED (via [recordCompletion]), so
/// generation never mutates persistent state.
abstract class RotationMemoryRepository {
  /// The current rotation-memory snapshot (empty on a fresh install).
  Future<RotationMemory> load();

  /// Records a completed [split] workout's [exercises] into rotation memory.
  /// [completionKey] deduplicates: recording the same completion twice is a
  /// no-op (mirrors the prototype's per-card-per-week completion key).
  Future<void> recordCompletion(
    String split,
    List<Exercise> exercises, {
    required String completionKey,
  });
}
