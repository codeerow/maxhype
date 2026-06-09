import '../equipment_type.dart';
import '../muscle_group.dart';
import 'session_set.dart';

class SessionExercise {
  /// Stable per-slot identity. Survives Replace — when the user swaps
  /// the underlying exercise mid-session, the slot keeps the same
  /// [slotId] but [exerciseId] points at the new catalog entry. This
  /// lets the session hold two slots pointing at the same exercise
  /// (e.g., the user replaced exercise B with Dumbbell Bench Press
  /// while exercise A — already logged Dumbbell Bench Press — is still
  /// in the list) without the UI collapsing them into one row.
  ///
  /// PR/history lookups continue to key on [exerciseId] because a PR
  /// is per exercise, not per slot.
  ///
  /// For backward compatibility with sessions persisted before this
  /// field existed, `fromJson` falls back to [exerciseId] when the
  /// stored payload has no `slotId`.
  final String slotId;
  final String exerciseId;
  final String name;
  final EquipmentType equipment;
  final List<MuscleGroup> muscleGroups;
  final int targetSets;

  /// Working sets. Drive `targetSets`, exercise completion, and PR detection.
  final List<SessionSet> sets;

  /// Warm-up rows. The user may add any number of warm-ups per exercise.
  /// Always shown in a dedicated section above the working sets in the UI.
  /// Excluded from PR detection.
  final List<SessionSet> warmups;

  /// Drop sets — additional rows logged after the working sets are finished.
  /// Rendered in a dedicated section below the working sets in the UI.
  /// Excluded from PR detection by default.
  final List<SessionSet> dropSets;

  final String notes;
  final bool completed;

  /// Default constructor. [slotId] is required in production but tests
  /// and older session payloads (pre-slot field) pass only
  /// [exerciseId] — they should use [SessionExercise.exerciseScoped]
  /// instead.
  const SessionExercise({
    required this.slotId,
    required this.exerciseId,
    required this.name,
    required this.equipment,
    this.muscleGroups = const [],
    required this.targetSets,
    required this.sets,
    this.warmups = const [],
    this.dropSets = const [],
    this.notes = '',
    this.completed = false,
  });

  // ----- Aggregate getters -----

  int get loggedSetsCount => sets.where((s) => s.isLogged).length;

  /// True when the exercise has at least one logged effective set or
  /// drop set. Warm-ups are intentionally excluded — they count as
  /// preparation, not workout activity, so a session with only warm-ups
  /// logged still trips the empty-finish guard. PR detection is unaffected;
  /// it has always excluded warm-ups and drop sets.
  bool get hasAnyLoggedSet =>
      loggedSetsCount > 0 ||
      dropSets.any((d) => d.isLogged);

  /// True when every working set has been logged. Warm-ups and drop sets
  /// do not affect this flag — they have their own per-row completion.
  bool get isAllSetsLogged =>
      sets.isNotEmpty && sets.every((s) => s.isLogged);

  /// True when at least one warmup row exists that has not been logged yet.
  bool get hasWarmupPending => warmups.any((w) => !w.isLogged);

  /// Most recent logged *effective* set — used to pre-fill the next set
  /// with the user's last load. Warm-ups and drop sets are ignored so a
  /// light warmup doesn't pollute the working-set pre-fill.
  SessionSet? get lastLoggedSet {
    SessionSet? out;
    for (final s in sets) {
      if (s.isLogged) out = s;
    }
    return out;
  }

  /// First non-logged effective set, or null when all working sets are logged.
  SessionSet? get firstUnloggedSet {
    for (final s in sets) {
      if (!s.isLogged) return s;
    }
    return null;
  }

  /// First non-logged warmup row, or null when no warmup is pending.
  SessionSet? get firstUnloggedWarmup {
    for (final w in warmups) {
      if (!w.isLogged) return w;
    }
    return null;
  }

  /// First non-logged drop set row, or null when no drop set is pending.
  SessionSet? get firstUnloggedDropSet {
    for (final d in dropSets) {
      if (!d.isLogged) return d;
    }
    return null;
  }

  /// Set the "Log Set / Done" button currently targets. Priority is:
  /// pending warmup → first unlogged effective set → first unlogged drop
  /// set. Returns null when every row across the three sections is logged.
  SessionSet? get currentTarget {
    if (hasWarmupPending) return firstUnloggedWarmup;
    final eff = firstUnloggedSet;
    if (eff != null) return eff;
    return firstUnloggedDropSet;
  }

  /// True when [currentTarget] is a warmup row.
  bool get isCurrentTargetWarmup =>
      currentTarget != null && currentTarget!.kind == SetKind.warmup;

  /// True when [currentTarget] is a drop-set row.
  bool get isCurrentTargetDropSet =>
      currentTarget != null && currentTarget!.kind == SetKind.dropSet;

  /// True when the next Log-Set tap will land on the last unlogged
  /// effective set. The button still logs that set; it does NOT mark the
  /// exercise done — that requires a separate Done tap (see
  /// [isAwaitingDoneConfirmation]).
  bool get isOnFinalEffectiveSet {
    if (hasWarmupPending) return false;
    return sets.where((s) => !s.isLogged).length == 1;
  }

  /// True when every row across warmups, effective sets, and drop sets is
  /// logged, and the exercise is not yet marked complete. In this state
  /// the bottom button shows "Done" and the next tap dispatches
  /// MarkExerciseDone (no further LogSet to fire).
  ///
  /// Per the milestone brief: "all sets should be logged or deleted" —
  /// drop sets and warmups are part of "all sets", so the user must clear
  /// every pending row before Done becomes available.
  bool get isAwaitingDoneConfirmation {
    if (completed) return false;
    if (sets.isEmpty) return false;
    if (!isAllSetsLogged) return false;
    if (hasWarmupPending) return false;
    if (dropSets.any((d) => !d.isLogged)) return false;
    return true;
  }

  // ----- copyWith / serialization -----

  SessionExercise copyWith({
    String? slotId,
    String? exerciseId,
    String? name,
    EquipmentType? equipment,
    List<MuscleGroup>? muscleGroups,
    int? targetSets,
    List<SessionSet>? sets,
    List<SessionSet>? warmups,
    List<SessionSet>? dropSets,
    String? notes,
    bool? completed,
  }) {
    return SessionExercise(
      slotId: slotId ?? this.slotId,
      exerciseId: exerciseId ?? this.exerciseId,
      name: name ?? this.name,
      equipment: equipment ?? this.equipment,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      targetSets: targetSets ?? this.targetSets,
      sets: sets ?? this.sets,
      warmups: warmups ?? this.warmups,
      dropSets: dropSets ?? this.dropSets,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'exerciseId': exerciseId,
        'name': name,
        'equipment': equipment.name,
        'muscleGroups': muscleGroups.map((m) => m.name).toList(),
        'targetSets': targetSets,
        'sets': sets.map((s) => s.toJson()).toList(),
        'warmups': warmups.map((w) => w.toJson()).toList(),
        'dropSets': dropSets.map((d) => d.toJson()).toList(),
        'notes': notes,
        'completed': completed,
      };

  factory SessionExercise.fromJson(Map<String, dynamic> json) {
    final exerciseId = json['exerciseId'] as String;
    return SessionExercise(
      // Backward-compat: sessions persisted before this field existed
      // didn't store slotId; default to exerciseId so an in-flight
      // restored session keeps working without a slot collision.
      slotId: (json['slotId'] as String?) ?? exerciseId,
      exerciseId: exerciseId,
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
      warmups: (json['warmups'] as List<dynamic>?)
              ?.map((e) => SessionSet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      dropSets: (json['dropSets'] as List<dynamic>?)
              ?.map((e) => SessionSet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      notes: (json['notes'] as String?) ?? '',
      completed: (json['completed'] as bool?) ?? false,
    );
  }
}
