import 'session_set.dart';

/// Pending edits to a single exercise made on the preview screen
/// (milestone Phase 3 Part 3, Item 6). Held in [WorkoutPreviewBloc]
/// until the user taps Start Workout — at that point the drafts are
/// merged into the freshly-created [WorkoutSession].
///
/// A draft carries the user's intent: which weight / reps they
/// pre-filled, plus any rows they added or removed before starting.
/// Nothing here is persisted to disk; the moment Start is pressed the
/// preview bloc clears, and the session bloc owns the data from then
/// on.
class PreviewExerciseDraft {
  final String exerciseId;
  final List<SessionSet> sets;
  final List<SessionSet> warmups;
  final List<SessionSet> dropSets;
  final String notes;

  const PreviewExerciseDraft({
    required this.exerciseId,
    this.sets = const [],
    this.warmups = const [],
    this.dropSets = const [],
    this.notes = '',
  });

  PreviewExerciseDraft copyWith({
    List<SessionSet>? sets,
    List<SessionSet>? warmups,
    List<SessionSet>? dropSets,
    String? notes,
  }) {
    return PreviewExerciseDraft(
      exerciseId: exerciseId,
      sets: sets ?? this.sets,
      warmups: warmups ?? this.warmups,
      dropSets: dropSets ?? this.dropSets,
      notes: notes ?? this.notes,
    );
  }
}
