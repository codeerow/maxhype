/// One-shot signal emitted by `WorkoutSessionBloc.prSignals` when a
/// freshly logged set beats the previous personal record for its
/// exercise. Subscribers (the logging screen) animate the row, fire
/// the celebratory haptic, and show a short "NEW PR" banner.
class PrAchievedSignal {
  final String exerciseId;
  final String setId;
  final double weight;
  final int reps;

  const PrAchievedSignal({
    required this.exerciseId,
    required this.setId,
    required this.weight,
    required this.reps,
  });
}
