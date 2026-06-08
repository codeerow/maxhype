import '../models/workout_completion.dart';

/// Persistence interface for per-workout completion records (the
/// "Completed · 17 mins" state on the home carousel). Backed by
/// `LocalWorkoutCompletionRepository` in production; mocked or in-memory
/// in tests.
abstract class WorkoutCompletionRepository {
  /// All completion records currently on disk, keyed by workoutId.
  /// Records older than the current ISO week are still returned —
  /// callers decide whether to filter via [WorkoutCompletion.completedAt]
  /// and [isInSameWeek] (e.g., the home screen filters to "this week"
  /// per clarification 1.2).
  Future<Map<String, WorkoutCompletion>> loadAll();

  /// Upsert the completion for a given workoutId. Per clarification
  /// 1.3, when the same workout is finished more than once in a week
  /// the latest completion (with the latest duration) replaces the
  /// earlier one — callers just pass the new record and the repo
  /// overwrites the existing key.
  Future<void> upsert(WorkoutCompletion completion);
}
