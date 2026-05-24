/// One link in the per-exercise PR history kept by the workout session bloc.
///
/// Each entry references the one it beat via [previousId]. The bloc keeps
/// entries in a flat `Map<id, PrEntry>` and one head pointer per exercise,
/// so rolling back to a prior PR is just hopping along [previousId] until
/// a still-live entry is found.
///
/// [setId] is `null` for the baseline entry loaded from history (it was
/// achieved in some prior, archived session — there is no live set to tie
/// it to inside the current session).
class PrEntry {
  final String id;
  final String exerciseId;
  final String? setId;
  final double weight;
  final int reps;
  final DateTime achievedAt;
  final String? previousId;

  const PrEntry({
    required this.id,
    required this.exerciseId,
    required this.setId,
    required this.weight,
    required this.reps,
    required this.achievedAt,
    required this.previousId,
  });
}
