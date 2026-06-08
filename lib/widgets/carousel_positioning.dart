import '../models/workout.dart';
import '../models/workout_completion.dart';

/// Pure helpers behind the home carousel's auto-positioning (milestone
/// Phase 3 Part 3, Item 3). Extracted so the rules can be pinned by
/// unit tests without spinning up a widget tree.

/// Index of the workout the carousel should focus when mounting with
/// an active session. Returns null if [activeWorkoutId] is null or not
/// found in [workouts].
int? activeCardIndex({
  required List<Workout> workouts,
  required String? activeWorkoutId,
}) {
  if (activeWorkoutId == null) return null;
  final idx = workouts.indexWhere((w) => w.id == activeWorkoutId);
  return idx < 0 ? null : idx;
}

/// Pick the workout the carousel should slide to after a finish.
///
/// Semantics — the **first** workout in carousel order that has no
/// completion record in the current ISO week, skipping the one that
/// was just finished. This walks the list left-to-right rather than
/// scanning forward-from-[fromIndex], so a user who finishes the
/// second workout while the first is still incomplete will be sent
/// back to the first one (clarification 3.7 — "the next not
/// completed workout" — interpreted as "next remaining in the plan",
/// not "next after the one you just did").
///
/// Returns null when every other workout is already completed this
/// week (brief §3 — "stay on the completed final card").
int? nextNotCompletedIndex({
  required List<Workout> workouts,
  required int fromIndex,
  required Map<String, WorkoutCompletion> completions,
  required DateTime now,
}) {
  if (workouts.length < 2) return null;
  for (var i = 0; i < workouts.length; i++) {
    if (i == fromIndex) continue;
    final w = workouts[i];
    final c = completions[w.id];
    final completedThisWeek =
        c != null && isInSameWeek(c.completedAt, now);
    if (!completedThisWeek) return i;
  }
  return null;
}
