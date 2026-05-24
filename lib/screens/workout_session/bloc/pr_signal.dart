/// Base type for one-shot PR side-channel events emitted by
/// `WorkoutSessionBloc.prSignals`.
sealed class PrSignal {
  const PrSignal();
}

/// Emitted when a freshly logged set beats the previous personal record
/// for its exercise. Subscribers (the logging screen) animate the row,
/// fire the celebratory haptic, and show a short "NEW PR" banner.
class PrAchievedSignal extends PrSignal {
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

/// Emitted when a PR is rolled back — the user deleted the set that
/// produced it. Subscribers should drop any "this set was a PR" state
/// keyed on [setId] (fire icon, gold pill, parked celebration).
class PrRevokedSignal extends PrSignal {
  final String exerciseId;
  final String setId;

  const PrRevokedSignal({
    required this.exerciseId,
    required this.setId,
  });
}
