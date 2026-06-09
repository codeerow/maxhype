import '../../models/session/session_exercise.dart';
import '../../models/session/workout_session.dart';

/// Decide which slot the user should land on when they tap the floating
/// "WORKOUT IN PROGRESS" bar (milestone Phase 3 Part 3, Item 5).
///
/// Returns a [SessionExercise.slotId] (or null when the session has no
/// exercises). Slot identity — not catalog exerciseId — is what the
/// session screen and logging route anchor on, so two slots that point
/// at the same catalog exercise can be navigated independently.
///
/// Brief §5 — three-tier priority:
///   1. The currently active slot (`session.activeExerciseId`, which
///      stores a slotId).
///   2. The slot whose most recent set was logged most recently.
///   3. The first slot that isn't already complete.
String? resumeTargetExerciseId(WorkoutSession session) {
  if (session.exercises.isEmpty) return null;

  final activeSlot = session.activeExerciseId;
  if (activeSlot != null &&
      session.exercises.any((e) => e.slotId == activeSlot && !e.completed)) {
    return activeSlot;
  }

  final lastLogged = _lastLoggedSlotId(session.exercises);
  if (lastLogged != null) return lastLogged;

  // No logged sets anywhere yet — drop the user into the first slot
  // that's not already marked complete (brief §5).
  for (final ex in session.exercises) {
    if (!ex.completed) return ex.slotId;
  }
  // Every slot is somehow completed — fall back to the very first one
  // so the bar still routes somewhere sensible.
  return session.exercises.first.slotId;
}

String? _lastLoggedSlotId(List<SessionExercise> exercises) {
  DateTime? bestAt;
  String? bestId;
  for (final ex in exercises) {
    if (ex.completed) continue;
    final latest = _latestLogTimestamp(ex);
    if (latest == null) continue;
    if (bestAt == null || latest.isAfter(bestAt)) {
      bestAt = latest;
      bestId = ex.slotId;
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
