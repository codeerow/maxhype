import '../equipment_type.dart';
import '../muscle_group.dart';
import 'session_set.dart';

class SessionExercise {
  final String exerciseId;
  final String name;
  final EquipmentType equipment;
  final List<MuscleGroup> muscleGroups;
  final int targetSets;
  final List<SessionSet> sets;
  final SessionSet? warmupSet;
  final String notes;
  final bool completed;

  const SessionExercise({
    required this.exerciseId,
    required this.name,
    required this.equipment,
    this.muscleGroups = const [],
    required this.targetSets,
    required this.sets,
    this.warmupSet,
    this.notes = '',
    this.completed = false,
  });

  // ----- Aggregate getters -----

  int get loggedSetsCount => sets.where((s) => s.isLogged).length;

  bool get hasAnyLoggedSet =>
      loggedSetsCount > 0 || (warmupSet?.isLogged ?? false);

  bool get isAllSetsLogged =>
      sets.isNotEmpty && sets.every((s) => s.isLogged);

  bool get hasWarmupPending =>
      warmupSet != null && !warmupSet!.isLogged;

  /// Most recent logged set in this exercise (warmup ignored — used for
  /// pre-fill defaults so the next set picks up the user's last load).
  SessionSet? get lastLoggedSet {
    SessionSet? out;
    for (final s in sets) {
      if (s.isLogged) out = s;
    }
    return out;
  }

  /// First non-logged effective set, or null when all are logged.
  SessionSet? get firstUnloggedSet {
    for (final s in sets) {
      if (!s.isLogged) return s;
    }
    return null;
  }

  /// Set the "Log Set / Done" button currently targets — warmup if it's
  /// pending, otherwise the first non-logged effective set.
  SessionSet? get currentTarget {
    if (hasWarmupPending) return warmupSet;
    return firstUnloggedSet;
  }

  /// True when [currentTarget] is the warmup row.
  bool get isCurrentTargetWarmup => hasWarmupPending;

  /// True when the next Log-Set tap will land on the last unlogged
  /// effective set. The button still logs that set; it does NOT mark the
  /// exercise done — that requires a separate Done tap (see
  /// [isAwaitingDoneConfirmation]).
  bool get isOnFinalEffectiveSet {
    if (hasWarmupPending) return false;
    return sets.where((s) => !s.isLogged).length == 1;
  }

  /// True when every effective set is logged, warmup is satisfied, and
  /// the exercise is not yet marked complete. In this state the bottom
  /// button shows "Done" and the next tap dispatches MarkExerciseDone
  /// (no further LogSet to fire).
  bool get isAwaitingDoneConfirmation =>
      !completed && !hasWarmupPending && isAllSetsLogged;

  // ----- copyWith / serialization -----

  SessionExercise copyWith({
    String? exerciseId,
    String? name,
    EquipmentType? equipment,
    List<MuscleGroup>? muscleGroups,
    int? targetSets,
    List<SessionSet>? sets,
    Object? warmupSet = _sentinel,
    String? notes,
    bool? completed,
  }) {
    return SessionExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      name: name ?? this.name,
      equipment: equipment ?? this.equipment,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      targetSets: targetSets ?? this.targetSets,
      sets: sets ?? this.sets,
      warmupSet: identical(warmupSet, _sentinel)
          ? this.warmupSet
          : warmupSet as SessionSet?,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'equipment': equipment.name,
        'muscleGroups': muscleGroups.map((m) => m.name).toList(),
        'targetSets': targetSets,
        'sets': sets.map((s) => s.toJson()).toList(),
        'warmupSet': warmupSet?.toJson(),
        'notes': notes,
        'completed': completed,
      };

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      SessionExercise(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        equipment: EquipmentType.values.firstWhere(
          (e) => e.name == json['equipment'],
          orElse: () => EquipmentType.bodyweight,
        ),
        muscleGroups: (json['muscleGroups'] as List<dynamic>?)
                ?.map(
                  (m) => MuscleGroup.values.firstWhere(
                    (v) => v.name == m,
                    orElse: () => MuscleGroup.chest,
                  ),
                )
                .toList() ??
            const [],
        targetSets: json['targetSets'] as int,
        sets: (json['sets'] as List<dynamic>)
            .map((e) => SessionSet.fromJson(e as Map<String, dynamic>))
            .toList(),
        warmupSet: json['warmupSet'] == null
            ? null
            : SessionSet.fromJson(json['warmupSet'] as Map<String, dynamic>),
        notes: (json['notes'] as String?) ?? '',
        completed: (json['completed'] as bool?) ?? false,
      );
}

const Object _sentinel = Object();
