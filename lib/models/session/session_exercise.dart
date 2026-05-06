import '../equipment_type.dart';
import 'session_set.dart';

class SessionExercise {
  final String exerciseId;
  final String name;
  final EquipmentType equipment;
  final int targetSets;
  final List<SessionSet> sets;
  final SessionSet? warmupSet;
  final String notes;
  final bool completed;

  const SessionExercise({
    required this.exerciseId,
    required this.name,
    required this.equipment,
    required this.targetSets,
    required this.sets,
    this.warmupSet,
    this.notes = '',
    this.completed = false,
  });

  int get loggedSetsCount => sets.where((s) => s.isLogged).length;

  bool get hasAnyLoggedSet =>
      loggedSetsCount > 0 || (warmupSet?.isLogged ?? false);

  SessionExercise copyWith({
    String? exerciseId,
    String? name,
    EquipmentType? equipment,
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
