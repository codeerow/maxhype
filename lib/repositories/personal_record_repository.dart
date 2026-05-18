import '../models/session/personal_record.dart';

abstract class PersonalRecordRepository {
  /// Best PR (highest estimated 1RM) for [exerciseId] across all archived
  /// workout history. Null if the exercise has never been logged.
  Future<PersonalRecord?> bestFor(String exerciseId);

  /// Drop any in-memory caches so the next read scans the source again.
  /// Called after the workout-session repository archives a finished
  /// session — at that point the previous "best" might no longer be best.
  void invalidate();
}
