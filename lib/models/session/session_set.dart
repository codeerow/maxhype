/// What role a [SessionSet] plays in an exercise.
///
/// - [effective] — a working set; counts toward exercise completion and is
///   eligible for personal-record detection.
/// - [warmup] — a warm-up row; the user may log multiple warm-ups per
///   exercise. Excluded from PR detection.
/// - [dropSet] — a drop set logged after the working sets are done.
///   Excluded from PR detection by default.
enum SetKind { effective, warmup, dropSet }

extension SetKindStorage on SetKind {
  String get storageKey {
    switch (this) {
      case SetKind.effective:
        return 'effective';
      case SetKind.warmup:
        return 'warmup';
      case SetKind.dropSet:
        return 'dropSet';
    }
  }

  static SetKind fromKey(String? key) {
    switch (key) {
      case 'warmup':
        return SetKind.warmup;
      case 'dropSet':
        return SetKind.dropSet;
      default:
        return SetKind.effective;
    }
  }
}

class SessionSet {
  final String id;
  final SetKind kind;
  final double? weight;
  final int? reps;
  final DateTime? loggedAt;

  const SessionSet({
    required this.id,
    this.kind = SetKind.effective,
    this.weight,
    this.reps,
    this.loggedAt,
  });

  bool get isLogged => loggedAt != null;
  bool get isFilled => weight != null && reps != null;

  SessionSet copyWith({
    String? id,
    SetKind? kind,
    Object? weight = _sentinel,
    Object? reps = _sentinel,
    Object? loggedAt = _sentinel,
  }) {
    return SessionSet(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      weight: identical(weight, _sentinel) ? this.weight : weight as double?,
      reps: identical(reps, _sentinel) ? this.reps : reps as int?,
      loggedAt: identical(loggedAt, _sentinel)
          ? this.loggedAt
          : loggedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.storageKey,
        'weight': weight,
        'reps': reps,
        'loggedAt': loggedAt?.toIso8601String(),
      };

  factory SessionSet.fromJson(Map<String, dynamic> json) => SessionSet(
        id: json['id'] as String,
        kind: SetKindStorage.fromKey(json['kind'] as String?),
        weight: (json['weight'] as num?)?.toDouble(),
        reps: json['reps'] as int?,
        loggedAt: json['loggedAt'] == null
            ? null
            : DateTime.parse(json['loggedAt'] as String),
      );
}

const Object _sentinel = Object();
