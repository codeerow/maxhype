/// Personal record for a single exercise.
///
/// Primary metric is **highest weight**, with a reps tie-break so a heavier
/// single doesn't lose to a lighter but longer set of the same weight. An
/// estimated 1RM (Brzycki) is exposed as a secondary indicator for future
/// UI (charts, "estimated 1RM" rows), but isn't used to gate "is PR".
class PersonalRecord {
  final String exerciseId;
  final double weight;
  final int reps;
  final DateTime achievedAt;

  const PersonalRecord({
    required this.exerciseId,
    required this.weight,
    required this.reps,
    required this.achievedAt,
  });

  /// Estimated 1RM (Brzycki). Returns 0 for invalid inputs.
  double get oneRm => brzycki(weight, reps);

  /// Returns true if `(weight, reps)` would beat this record:
  ///   1. strictly heavier weight is always a new PR
  ///   2. same weight but more reps is also a new PR
  bool isBeatenBy({required double weight, required int reps}) {
    if (weight <= 0 || reps <= 0) return false;
    if (weight > this.weight) return true;
    if (weight == this.weight && reps > this.reps) return true;
    return false;
  }

  /// Brzycki estimated 1RM. Returns 0 for invalid inputs (weight ≤ 0,
  /// reps ≤ 0, or reps ≥ 37 where the formula breaks down).
  static double brzycki(double weight, int reps) {
    if (weight <= 0 || reps <= 0 || reps >= 37) return 0;
    return weight * 36.0 / (37 - reps);
  }
}
