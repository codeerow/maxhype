enum RecoveryStatus {
  ready,
  almostReady,
  notReady,
}

class RecoveryInfo {
  final RecoveryStatus status;
  final double percentage;
  final String description;

  RecoveryInfo({
    required this.status,
    required this.percentage,
    required this.description,
  });

  String get statusText {
    switch (status) {
      case RecoveryStatus.ready:
        return 'READY TO TRAIN';
      case RecoveryStatus.almostReady:
        return 'ALMOST READY';
      case RecoveryStatus.notReady:
        return 'NOT READY';
    }
  }
}

class Workout {
  final String title;
  final String subtitle;
  final String duration;
  final int exerciseCount;
  final RecoveryInfo recoveryInfo;

  Workout({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.exerciseCount,
    required this.recoveryInfo,
  });
}
