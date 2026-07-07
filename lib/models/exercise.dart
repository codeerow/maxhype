import 'muscle_group.dart';
import 'equipment_type.dart';
import 'generator/generator_metadata.dart';

class Exercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double weight; // in kg
  final List<MuscleGroup> muscleGroups;
  final String? imageUrl;
  final EquipmentType equipmentType;
  final int rating; // Conditional rating (likes count)

  /// Generator-only metadata (category, tier, movement group, experience
  /// gating, replacement flags). Null for exercises not sourced from the
  /// generator library — the rest of the app never depends on it, so existing
  /// call sites and screens are unaffected.
  final GeneratorMetadata? generatorMeta;

  Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.muscleGroups,
    this.imageUrl,
    required this.equipmentType,
    required this.rating,
    this.generatorMeta,
  });

  Exercise copyWith({
    String? id,
    String? name,
    int? sets,
    int? reps,
    double? weight,
    List<MuscleGroup>? muscleGroups,
    String? imageUrl,
    EquipmentType? equipmentType,
    int? rating,
    GeneratorMetadata? generatorMeta,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      imageUrl: imageUrl ?? this.imageUrl,
      equipmentType: equipmentType ?? this.equipmentType,
      rating: rating ?? this.rating,
      generatorMeta: generatorMeta ?? this.generatorMeta,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'muscleGroups': muscleGroups.map((m) => m.name).toList(),
        'imageUrl': imageUrl,
        'equipmentType': equipmentType.name,
        'rating': rating,
        'generatorMeta': generatorMeta?.toJson(),
      };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      weight: (json['weight'] as num).toDouble(),
      muscleGroups: (json['muscleGroups'] as List<dynamic>)
          .map((m) => MuscleGroup.values.byName(m as String))
          .toList(),
      imageUrl: json['imageUrl'] as String?,
      equipmentType: EquipmentType.values.byName(json['equipmentType'] as String),
      rating: json['rating'] as int,
      generatorMeta: json['generatorMeta'] == null
          ? null
          : GeneratorMetadata.fromJson(
              json['generatorMeta'] as Map<String, dynamic>),
    );
  }
}
