import 'muscle_group.dart';
import 'equipment_type.dart';

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
    );
  }
}
