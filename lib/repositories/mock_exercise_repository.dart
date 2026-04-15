import '../models/exercise.dart';
import '../models/muscle_group.dart';
import '../models/equipment_type.dart';
import 'exercise_repository.dart';

class MockExerciseRepository implements ExerciseRepository {
  static final List<Exercise> _exercises = [
    // ===== CHEST EXERCISES =====
    Exercise(
      id: 'ex_001',
      name: 'Barbell Bench Press',
      sets: 4,
      reps: 8,
      weight: 80.0,
      muscleGroups: [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
      equipmentType: EquipmentType.barbell,
      rating: 5000,
    ),
    Exercise(
      id: 'ex_002',
      name: 'Dumbbell Bench Press',
      sets: 4,
      reps: 10,
      weight: 32.5,
      muscleGroups: [MuscleGroup.chest, MuscleGroup.triceps],
      equipmentType: EquipmentType.dumbbell,
      rating: 4800,
    ),
    Exercise(
      id: 'ex_003',
      name: 'Incline Dumbbell Press',
      sets: 4,
      reps: 10,
      weight: 30.0,
      muscleGroups: [MuscleGroup.chest, MuscleGroup.shoulders],
      equipmentType: EquipmentType.dumbbell,
      rating: 4500,
    ),
    Exercise(
      id: 'ex_004',
      name: 'Decline Barbell Bench Press',
      sets: 4,
      reps: 8,
      weight: 70.0,
      muscleGroups: [MuscleGroup.chest],
      equipmentType: EquipmentType.barbell,
      rating: 3800,
    ),
    Exercise(
      id: 'ex_005',
      name: 'Cable Chest Fly',
      sets: 3,
      reps: 12,
      weight: 15.0,
      muscleGroups: [MuscleGroup.chest],
      equipmentType: EquipmentType.cable,
      rating: 4200,
    ),
    Exercise(
      id: 'ex_006',
      name: 'Incline Cable Chest Press',
      sets: 3,
      reps: 12,
      weight: 20.0,
      muscleGroups: [MuscleGroup.chest],
      equipmentType: EquipmentType.cable,
      rating: 3500,
    ),
    Exercise(
      id: 'ex_007',
      name: 'Pec Deck Machine',
      sets: 3,
      reps: 12,
      weight: 50.0,
      muscleGroups: [MuscleGroup.chest],
      equipmentType: EquipmentType.machine,
      rating: 3200,
    ),
    Exercise(
      id: 'ex_008',
      name: 'Push-ups',
      sets: 3,
      reps: 15,
      weight: 0.0,
      muscleGroups: [MuscleGroup.chest, MuscleGroup.triceps],
      equipmentType: EquipmentType.bodyweight,
      rating: 4600,
    ),

    // ===== SHOULDER EXERCISES =====
    Exercise(
      id: 'ex_009',
      name: 'Standing Dumbbell Shoulder Press',
      sets: 4,
      reps: 8,
      weight: 25.0,
      muscleGroups: [MuscleGroup.shoulders, MuscleGroup.triceps],
      equipmentType: EquipmentType.dumbbell,
      rating: 4700,
    ),
    Exercise(
      id: 'ex_010',
      name: 'Barbell Shoulder Press',
      sets: 4,
      reps: 8,
      weight: 55.0,
      muscleGroups: [MuscleGroup.shoulders, MuscleGroup.triceps],
      equipmentType: EquipmentType.barbell,
      rating: 4500,
    ),
    Exercise(
      id: 'ex_011',
      name: 'Lateral Dumbbell Raise',
      sets: 3,
      reps: 12,
      weight: 12.5,
      muscleGroups: [MuscleGroup.shoulders],
      equipmentType: EquipmentType.dumbbell,
      rating: 4300,
    ),
    Exercise(
      id: 'ex_012',
      name: 'Cable Lateral Raise',
      sets: 3,
      reps: 12,
      weight: 7.5,
      muscleGroups: [MuscleGroup.shoulders],
      equipmentType: EquipmentType.cable,
      rating: 3700,
    ),
    Exercise(
      id: 'ex_013',
      name: 'Front Dumbbell Raise',
      sets: 3,
      reps: 12,
      weight: 10.0,
      muscleGroups: [MuscleGroup.shoulders],
      equipmentType: EquipmentType.dumbbell,
      rating: 3500,
    ),
    Exercise(
      id: 'ex_014',
      name: 'Reverse Pec Deck',
      sets: 3,
      reps: 12,
      weight: 40.0,
      muscleGroups: [MuscleGroup.shoulders],
      equipmentType: EquipmentType.machine,
      rating: 3400,
    ),

    // ===== TRICEPS EXERCISES =====
    Exercise(
      id: 'ex_015',
      name: 'Tricep Pushdown',
      sets: 3,
      reps: 12,
      weight: 30.0,
      muscleGroups: [MuscleGroup.triceps],
      equipmentType: EquipmentType.cable,
      rating: 4500,
    ),
    Exercise(
      id: 'ex_016',
      name: 'Dips',
      sets: 3,
      reps: 10,
      weight: 0.0,
      muscleGroups: [MuscleGroup.triceps, MuscleGroup.chest],
      equipmentType: EquipmentType.bodyweight,
      rating: 4600,
    ),
    Exercise(
      id: 'ex_017',
      name: 'Overhead Dumbbell Tricep Extension',
      sets: 3,
      reps: 12,
      weight: 20.0,
      muscleGroups: [MuscleGroup.triceps],
      equipmentType: EquipmentType.dumbbell,
      rating: 4000,
    ),
    Exercise(
      id: 'ex_018',
      name: 'Skull Crushers',
      sets: 3,
      reps: 10,
      weight: 25.0,
      muscleGroups: [MuscleGroup.triceps],
      equipmentType: EquipmentType.barbell,
      rating: 3900,
    ),

    // ===== BACK EXERCISES =====
    Exercise(
      id: 'ex_019',
      name: 'Deadlift',
      sets: 4,
      reps: 6,
      weight: 120.0,
      muscleGroups: [MuscleGroup.back, MuscleGroup.hamstrings, MuscleGroup.glutes],
      equipmentType: EquipmentType.barbell,
      rating: 5000,
    ),
    Exercise(
      id: 'ex_020',
      name: 'Pull-ups',
      sets: 4,
      reps: 8,
      weight: 0.0,
      muscleGroups: [MuscleGroup.back, MuscleGroup.biceps],
      equipmentType: EquipmentType.bodyweight,
      rating: 4900,
    ),
    Exercise(
      id: 'ex_021',
      name: 'Barbell Row',
      sets: 4,
      reps: 8,
      weight: 70.0,
      muscleGroups: [MuscleGroup.back, MuscleGroup.biceps],
      equipmentType: EquipmentType.barbell,
      rating: 4700,
    ),
    Exercise(
      id: 'ex_022',
      name: 'Lat Pulldown',
      sets: 4,
      reps: 10,
      weight: 60.0,
      muscleGroups: [MuscleGroup.back, MuscleGroup.biceps],
      equipmentType: EquipmentType.cable,
      rating: 4500,
    ),
    Exercise(
      id: 'ex_023',
      name: 'Dumbbell Row',
      sets: 4,
      reps: 10,
      weight: 35.0,
      muscleGroups: [MuscleGroup.back, MuscleGroup.biceps],
      equipmentType: EquipmentType.dumbbell,
      rating: 4400,
    ),
    Exercise(
      id: 'ex_024',
      name: 'Seated Cable Row',
      sets: 4,
      reps: 10,
      weight: 55.0,
      muscleGroups: [MuscleGroup.back],
      equipmentType: EquipmentType.cable,
      rating: 4200,
    ),
    Exercise(
      id: 'ex_025',
      name: 'Face Pulls',
      sets: 3,
      reps: 15,
      weight: 20.0,
      muscleGroups: [MuscleGroup.back, MuscleGroup.shoulders],
      equipmentType: EquipmentType.cable,
      rating: 4000,
    ),
    Exercise(
      id: 'ex_026',
      name: 'T-Bar Row',
      sets: 4,
      reps: 8,
      weight: 50.0,
      muscleGroups: [MuscleGroup.back],
      equipmentType: EquipmentType.barbell,
      rating: 3800,
    ),

    // ===== BICEPS EXERCISES =====
    Exercise(
      id: 'ex_027',
      name: 'Barbell Curl',
      sets: 3,
      reps: 10,
      weight: 30.0,
      muscleGroups: [MuscleGroup.biceps],
      equipmentType: EquipmentType.barbell,
      rating: 4600,
    ),
    Exercise(
      id: 'ex_028',
      name: 'Dumbbell Curl',
      sets: 3,
      reps: 10,
      weight: 15.0,
      muscleGroups: [MuscleGroup.biceps],
      equipmentType: EquipmentType.dumbbell,
      rating: 4500,
    ),
    Exercise(
      id: 'ex_029',
      name: 'Hammer Curl',
      sets: 3,
      reps: 10,
      weight: 17.5,
      muscleGroups: [MuscleGroup.biceps, MuscleGroup.forearms],
      equipmentType: EquipmentType.dumbbell,
      rating: 4300,
    ),
    Exercise(
      id: 'ex_030',
      name: 'Cable Curl',
      sets: 3,
      reps: 12,
      weight: 25.0,
      muscleGroups: [MuscleGroup.biceps],
      equipmentType: EquipmentType.cable,
      rating: 4000,
    ),
    Exercise(
      id: 'ex_031',
      name: 'Preacher Curl',
      sets: 3,
      reps: 10,
      weight: 20.0,
      muscleGroups: [MuscleGroup.biceps],
      equipmentType: EquipmentType.barbell,
      rating: 3800,
    ),

    // ===== QUAD EXERCISES =====
    Exercise(
      id: 'ex_032',
      name: 'Barbell Squat',
      sets: 4,
      reps: 8,
      weight: 100.0,
      muscleGroups: [MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.hamstrings],
      equipmentType: EquipmentType.barbell,
      rating: 5000,
    ),
    Exercise(
      id: 'ex_033',
      name: 'Leg Press',
      sets: 4,
      reps: 10,
      weight: 150.0,
      muscleGroups: [MuscleGroup.quads, MuscleGroup.glutes],
      equipmentType: EquipmentType.machine,
      rating: 4600,
    ),
    Exercise(
      id: 'ex_034',
      name: 'Bulgarian Split Squat',
      sets: 3,
      reps: 10,
      weight: 20.0,
      muscleGroups: [MuscleGroup.quads, MuscleGroup.glutes],
      equipmentType: EquipmentType.dumbbell,
      rating: 4300,
    ),
    Exercise(
      id: 'ex_035',
      name: 'Leg Extension',
      sets: 3,
      reps: 12,
      weight: 50.0,
      muscleGroups: [MuscleGroup.quads],
      equipmentType: EquipmentType.machine,
      rating: 4100,
    ),
    Exercise(
      id: 'ex_036',
      name: 'Front Squat',
      sets: 4,
      reps: 8,
      weight: 70.0,
      muscleGroups: [MuscleGroup.quads, MuscleGroup.abs],
      equipmentType: EquipmentType.barbell,
      rating: 3900,
    ),

    // ===== HAMSTRING EXERCISES =====
    Exercise(
      id: 'ex_037',
      name: 'Romanian Deadlift',
      sets: 4,
      reps: 8,
      weight: 80.0,
      muscleGroups: [MuscleGroup.hamstrings, MuscleGroup.glutes],
      equipmentType: EquipmentType.barbell,
      rating: 4700,
    ),
    Exercise(
      id: 'ex_038',
      name: 'Leg Curl',
      sets: 3,
      reps: 12,
      weight: 40.0,
      muscleGroups: [MuscleGroup.hamstrings],
      equipmentType: EquipmentType.machine,
      rating: 4400,
    ),
    Exercise(
      id: 'ex_039',
      name: 'Nordic Hamstring Curl',
      sets: 3,
      reps: 6,
      weight: 0.0,
      muscleGroups: [MuscleGroup.hamstrings],
      equipmentType: EquipmentType.bodyweight,
      rating: 4000,
    ),

    // ===== GLUTE EXERCISES =====
    Exercise(
      id: 'ex_040',
      name: 'Hip Thrust',
      sets: 4,
      reps: 10,
      weight: 90.0,
      muscleGroups: [MuscleGroup.glutes, MuscleGroup.hamstrings],
      equipmentType: EquipmentType.barbell,
      rating: 4800,
    ),
    Exercise(
      id: 'ex_041',
      name: 'Glute Bridge',
      sets: 3,
      reps: 12,
      weight: 60.0,
      muscleGroups: [MuscleGroup.glutes],
      equipmentType: EquipmentType.barbell,
      rating: 4300,
    ),

    // ===== CALF EXERCISES =====
    Exercise(
      id: 'ex_042',
      name: 'Standing Calf Raise',
      sets: 4,
      reps: 15,
      weight: 80.0,
      muscleGroups: [MuscleGroup.calves],
      equipmentType: EquipmentType.machine,
      rating: 4200,
    ),
    Exercise(
      id: 'ex_043',
      name: 'Seated Calf Raise',
      sets: 3,
      reps: 15,
      weight: 40.0,
      muscleGroups: [MuscleGroup.calves],
      equipmentType: EquipmentType.machine,
      rating: 3900,
    ),

    // ===== ABS EXERCISES =====
    Exercise(
      id: 'ex_044',
      name: 'Cable Crunch',
      sets: 3,
      reps: 15,
      weight: 40.0,
      muscleGroups: [MuscleGroup.abs],
      equipmentType: EquipmentType.cable,
      rating: 4400,
    ),
    Exercise(
      id: 'ex_045',
      name: 'Hanging Leg Raise',
      sets: 3,
      reps: 12,
      weight: 0.0,
      muscleGroups: [MuscleGroup.abs],
      equipmentType: EquipmentType.bodyweight,
      rating: 4500,
    ),
    Exercise(
      id: 'ex_046',
      name: 'Plank',
      sets: 3,
      reps: 60,
      weight: 0.0,
      muscleGroups: [MuscleGroup.abs],
      equipmentType: EquipmentType.bodyweight,
      rating: 4300,
    ),
    Exercise(
      id: 'ex_047',
      name: 'Russian Twist',
      sets: 3,
      reps: 20,
      weight: 10.0,
      muscleGroups: [MuscleGroup.abs, MuscleGroup.obliques],
      equipmentType: EquipmentType.dumbbell,
      rating: 4000,
    ),
  ];

  @override
  List<Exercise> getAllExercises() {
    return List.unmodifiable(_exercises);
  }

  @override
  List<Exercise> getExercisesByMuscleGroup(MuscleGroup muscleGroup) {
    return _exercises
        .where((exercise) => exercise.muscleGroups.contains(muscleGroup))
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
  }

  @override
  List<Exercise> getTopExercisesByMuscleGroup(
    MuscleGroup muscleGroup, {
    int limit = 8,
  }) {
    final filtered = getExercisesByMuscleGroup(muscleGroup);
    return filtered.take(limit).toList();
  }

  @override
  Exercise? getExerciseById(String id) {
    try {
      return _exercises.firstWhere((exercise) => exercise.id == id);
    } catch (e) {
      return null;
    }
  }
}
