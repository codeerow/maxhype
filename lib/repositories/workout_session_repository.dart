import '../models/session/session_set.dart';
import '../models/session/workout_session.dart';

abstract class WorkoutSessionRepository {
  Future<WorkoutSession?> loadActive();

  Future<void> save(WorkoutSession session);

  Future<void> clearActive();

  Future<void> archiveFinished(WorkoutSession session);

  /// Most recent logged set for [exerciseId] across archived (finished)
  /// sessions. Returns null if the exercise has never been logged. Used by
  /// the logging screen to pre-fill weight/reps for new sets.
  Future<SessionSet?> lastLogFor(String exerciseId);
}
