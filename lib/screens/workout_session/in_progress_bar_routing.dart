import '../../models/session/session_exercise.dart';
import '../../models/session/workout_session.dart';

/// Decide which exercise the user should land on when they tap the
/// floating "WORKOUT IN PROGRESS" bar (milestone Phase 3 Part 3,
/// Item 5).
///
/// Brief §5 — three-tier priority:
///   1. The currently active exercise (`session.activeExerciseId`) —
///      "If the user was actively logging a specific exercise →
///       navigate to that exact exercise/logging screen".
///   2. The last exercise that received a logged set — "the same
///      logic as active exercise" (clarification 5.13).
///   3. The first incomplete exercise — "If workout started but no
///      exercise has been started/logged yet → route to the
///      first/next incomplete exercise".
///
/// Returns null only when the session has no exercises (bar is
/// invisible in that state, but the helper stays safe).
String? resumeTargetExerciseId(WorkoutSession session) {
  if (session.exercises.isEmpty) return null;

  final active = session.activeExerciseId;
  if (active != null &&
      session.exercises.any((e) => e.exerciseId == active && !e.completed)) {
    return active;
  }

  final lastLogged = _lastLoggedExerciseId(session.exercises);
  if (lastLogged != null) return lastLogged;

  // No logged sets anywhere yet — drop the user into the first
  // exercise that's not already marked complete (brief §5).
  for (final ex in session.exercises) {
    if (!ex.completed) return ex.exerciseId;
  }
  // Every exercise is somehow completed — fall back to the very
  // first one so the bar still routes somewhere sensible.
  return session.exercises.first.exerciseId;
}

String? _lastLoggedExerciseId(List<SessionExercise> exercises) {
  DateTime? bestAt;
  String? bestId;
  for (final ex in exercises) {
    if (ex.completed) continue;
    final latest = _latestLogTimestamp(ex);
    if (latest == null) continue;
    if (bestAt == null || latest.isAfter(bestAt)) {
      bestAt = latest;
      bestId = ex.exerciseId;
    }
  }
  return bestId;
}

DateTime? _latestLogTimestamp(SessionExercise ex) {
  DateTime? out;
  void consider(DateTime? t) {
    if (t == null) return;
    if (out == null || t.isAfter(out!)) out = t;
  }

  for (final s in ex.sets) {
    consider(s.loggedAt);
  }
  for (final w in ex.warmups) {
    consider(w.loggedAt);
  }
  for (final d in ex.dropSets) {
    consider(d.loggedAt);
  }
  return out;
}
