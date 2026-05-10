class SessionSet {
  final String id;
  final double? weight;
  final int? reps;
  final DateTime? loggedAt;

  const SessionSet({
    required this.id,
    this.weight,
    this.reps,
    this.loggedAt,
  });

  bool get isLogged => loggedAt != null;
  bool get isFilled => weight != null && reps != null;

  SessionSet copyWith({
    String? id,
    Object? weight = _sentinel,
    Object? reps = _sentinel,
    Object? loggedAt = _sentinel,
  }) {
    return SessionSet(
      id: id ?? this.id,
      weight: identical(weight, _sentinel) ? this.weight : weight as double?,
      reps: identical(reps, _sentinel) ? this.reps : reps as int?,
      loggedAt: identical(loggedAt, _sentinel)
          ? this.loggedAt
          : loggedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'weight': weight,
        'reps': reps,
        'loggedAt': loggedAt?.toIso8601String(),
      };

  factory SessionSet.fromJson(Map<String, dynamic> json) => SessionSet(
        id: json['id'] as String,
        weight: (json['weight'] as num?)?.toDouble(),
        reps: json['reps'] as int?,
        loggedAt: json['loggedAt'] == null
            ? null
            : DateTime.parse(json['loggedAt'] as String),
      );
}

const Object _sentinel = Object();
