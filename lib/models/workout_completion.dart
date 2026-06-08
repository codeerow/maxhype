/// Per-workout completion record stored on disk in
/// `workout_completion.json`. Drives the "Completed · 17 mins" state on
/// the home carousel (milestone Phase 3 Part 3, Item 1).
///
/// One entry per workoutId. When the user completes a workout the
/// session bloc upserts the latest record (clarification 1.3 — the
/// latest wall-clock duration wins when the same workout is finished
/// more than once in the same week).
class WorkoutCompletion {
  final String workoutId;
  final DateTime completedAt;
  final int durationSeconds;

  const WorkoutCompletion({
    required this.workoutId,
    required this.completedAt,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'workoutId': workoutId,
        'completedAt': completedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
      };

  factory WorkoutCompletion.fromJson(Map<String, dynamic> json) =>
      WorkoutCompletion(
        workoutId: json['workoutId'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
        durationSeconds: json['durationSeconds'] as int,
      );
}

/// ISO-8601 week numbering. The brief mandates a weekly reset
/// (clarification 1.2 — "just recover workouts every week"); two
/// timestamps fall in the same "completed window" iff they share an
/// ISO week.
///
/// Returns `(isoWeekYear, isoWeekNumber)` so callers can compare a
/// completion timestamp against `now` without serialising to a string.
({int year, int week}) isoWeekOf(DateTime instant) {
  // Work in the local zone — users live in one timezone at a time and
  // "this week" should match their wall clock, not UTC.
  final local = instant.toLocal();
  // ISO weeks run Monday–Sunday. Compute Thursday of the same week —
  // it's always in the ISO-week-numbering year.
  final dayOfWeek = local.weekday; // 1 = Monday, 7 = Sunday
  final thursday = DateTime(local.year, local.month, local.day)
      .add(Duration(days: 4 - dayOfWeek));
  // Day-of-year of that Thursday → week number.
  final firstThursday = _firstThursdayOf(thursday.year);
  final week = 1 + thursday.difference(firstThursday).inDays ~/ 7;
  return (year: thursday.year, week: week);
}

DateTime _firstThursdayOf(int year) {
  // Jan 4 always falls in ISO week 1 — walk to its Thursday.
  final jan4 = DateTime(year, 1, 4);
  final dayOfWeek = jan4.weekday;
  return jan4.add(Duration(days: 4 - dayOfWeek));
}

/// Whether [completedAt] is in the same ISO week as [now]. Used to
/// decide if a workout card should show its Completed state or revert
/// to Ready (the milestone defines "completed" as "completed this
/// week").
bool isInSameWeek(DateTime completedAt, DateTime now) {
  final a = isoWeekOf(completedAt);
  final b = isoWeekOf(now);
  return a.year == b.year && a.week == b.week;
}
