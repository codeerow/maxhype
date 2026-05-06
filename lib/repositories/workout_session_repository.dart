import '../models/session/workout_session.dart';

abstract class WorkoutSessionRepository {
  Future<WorkoutSession?> loadActive();

  Future<void> save(WorkoutSession session);

  Future<void> clearActive();

  Future<void> archiveFinished(WorkoutSession session);
}
