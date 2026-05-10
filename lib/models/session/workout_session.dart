import 'session_exercise.dart';
import 'session_warmup_type.dart';

enum SessionStatus { active, cancelled, finished }

extension SessionStatusKey on SessionStatus {
  String get key {
    switch (this) {
      case SessionStatus.active:
        return 'active';
      case SessionStatus.cancelled:
        return 'cancelled';
      case SessionStatus.finished:
        return 'finished';
    }
  }

  static SessionStatus fromKey(String? k) {
    switch (k) {
      case 'cancelled':
        return SessionStatus.cancelled;
      case 'finished':
        return SessionStatus.finished;
      default:
        return SessionStatus.active;
    }
  }
}

class WorkoutSession {
  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime startedAt;
  final List<SessionExercise> exercises;
  final String? activeExerciseId;
  final DateTime? activeRestEndsAt;
  final int restDurationSeconds;
  final WarmupType warmup;
  final SessionStatus status;
  final DateTime? finishedAt;

  const WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.startedAt,
    required this.exercises,
    this.activeExerciseId,
    this.activeRestEndsAt,
    this.restDurationSeconds = 120,
    this.warmup = WarmupType.none,
    this.status = SessionStatus.active,
    this.finishedAt,
  });

  WorkoutSession copyWith({
    String? id,
    String? workoutId,
    String? workoutName,
    DateTime? startedAt,
    List<SessionExercise>? exercises,
    Object? activeExerciseId = _sentinel,
    Object? activeRestEndsAt = _sentinel,
    int? restDurationSeconds,
    WarmupType? warmup,
    SessionStatus? status,
    Object? finishedAt = _sentinel,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      workoutName: workoutName ?? this.workoutName,
      startedAt: startedAt ?? this.startedAt,
      exercises: exercises ?? this.exercises,
      activeExerciseId: identical(activeExerciseId, _sentinel)
          ? this.activeExerciseId
          : activeExerciseId as String?,
      activeRestEndsAt: identical(activeRestEndsAt, _sentinel)
          ? this.activeRestEndsAt
          : activeRestEndsAt as DateTime?,
      restDurationSeconds: restDurationSeconds ?? this.restDurationSeconds,
      warmup: warmup ?? this.warmup,
      status: status ?? this.status,
      finishedAt: identical(finishedAt, _sentinel)
          ? this.finishedAt
          : finishedAt as DateTime?,
    );
  }

  Duration elapsedSince(DateTime now) => now.difference(startedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'workoutId': workoutId,
        'workoutName': workoutName,
        'startedAt': startedAt.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'activeExerciseId': activeExerciseId,
        'activeRestEndsAt': activeRestEndsAt?.toIso8601String(),
        'restDurationSeconds': restDurationSeconds,
        'warmup': warmup.storageKey,
        'status': status.key,
        'finishedAt': finishedAt?.toIso8601String(),
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] as String,
        workoutId: json['workoutId'] as String,
        workoutName: json['workoutName'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        exercises: (json['exercises'] as List<dynamic>)
            .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeExerciseId: json['activeExerciseId'] as String?,
        activeRestEndsAt: json['activeRestEndsAt'] == null
            ? null
            : DateTime.parse(json['activeRestEndsAt'] as String),
        restDurationSeconds: (json['restDurationSeconds'] as int?) ?? 120,
        warmup: WarmupTypeExtension.fromKey(json['warmup'] as String?),
        status: SessionStatusKey.fromKey(json['status'] as String?),
        finishedAt: json['finishedAt'] == null
            ? null
            : DateTime.parse(json['finishedAt'] as String),
      );
}

const Object _sentinel = Object();
