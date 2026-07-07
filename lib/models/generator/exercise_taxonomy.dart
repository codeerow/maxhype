import '../muscle_group.dart';
import '../equipment_type.dart';

/// Generator taxonomy ported from the web prototype.
///
/// The prototype describes exercises with *finer-grained* string vocabularies
/// than the app's existing coarse enums (13 [MuscleGroup]s, 5 [EquipmentType]s):
/// 15 body parts, 12 equipment kinds, 35 categories, and dozens of movement
/// groups. To port the generator without losing fidelity — and without
/// disturbing the muscle atlas / Replace UI that switch on the coarse enums —
/// these richer taxonomies are kept as their own value types and *mapped down*
/// to the coarse enums where the existing UI needs them.

/// Compound vs isolation. Drives set-density (compound vs isolation set counts)
/// and tier logic in the generator.
enum ExerciseType {
  compound,
  isolation;

  String get wireValue => this == ExerciseType.compound ? 'compound' : 'isolation';

  static ExerciseType fromWire(String value) =>
      value == 'compound' ? ExerciseType.compound : ExerciseType.isolation;
}

/// Selection priority tier. A = primary compounds, B = secondary compounds,
/// C = isolation/accessory. The generator fills high-tier slots first and
/// applies experience-based tier rules to the opening slots.
enum ExerciseTier {
  a,
  b,
  c;

  String get wireValue {
    switch (this) {
      case ExerciseTier.a:
        return 'A';
      case ExerciseTier.b:
        return 'B';
      case ExerciseTier.c:
        return 'C';
    }
  }

  static ExerciseTier fromWire(String value) {
    switch (value.toUpperCase()) {
      case 'A':
        return ExerciseTier.a;
      case 'B':
        return ExerciseTier.b;
      default:
        return ExerciseTier.c;
    }
  }
}

/// The prototype's body-part label (15 values, e.g. "Abductors", "Trapezius").
/// Kept as a thin string wrapper: the generator reasons over the raw label,
/// while [toMuscleGroup] projects onto the app's 13-value [MuscleGroup] enum so
/// the muscle atlas and Replace-by-muscle UI keep working unchanged.
extension type const BodyPart(String label) {
  /// Maps a prototype body part onto the app's coarse [MuscleGroup].
  /// Returns null for labels with no direct coarse equivalent (the caller
  /// falls back to leaving the coarse list untouched).
  MuscleGroup? toMuscleGroup() {
    switch (label) {
      case 'Chest':
        return MuscleGroup.chest;
      case 'Shoulders':
        return MuscleGroup.shoulders;
      case 'Triceps':
        return MuscleGroup.triceps;
      case 'Back':
        return MuscleGroup.back;
      case 'Biceps':
        return MuscleGroup.biceps;
      case 'Forearms':
        return MuscleGroup.forearms;
      case 'Quads':
        return MuscleGroup.quads;
      case 'Hamstrings':
        return MuscleGroup.hamstrings;
      case 'Glutes':
        return MuscleGroup.glutes;
      case 'Calves':
        return MuscleGroup.calves;
      case 'Abs':
        return MuscleGroup.abs;
      case 'Lower Back':
        return MuscleGroup.lowerBack;
      case 'Trapezius':
        return MuscleGroup.back; // traps read as back in the coarse atlas
      case 'Abductors':
      case 'Adductors':
        return MuscleGroup.glutes; // hip abd/add nearest coarse bucket
      default:
        return null;
    }
  }
}

/// The prototype's equipment label (12 values). [toEquipmentType] projects onto
/// the app's 5-value [EquipmentType]; finer kinds (Smith Machine, Plate-Loaded,
/// EZ Bar, Trap Bar, Landmine, Medicine Ball, Stability Ball) collapse onto the
/// nearest coarse bucket so existing screens render correctly, while the raw
/// [label] stays available to the generator for equipment-continuity rules.
extension type const GeneratorEquipment(String label) {
  EquipmentType toEquipmentType() {
    switch (label) {
      case 'Dumbbell':
        return EquipmentType.dumbbell;
      case 'Barbell':
      case 'EZ Bar':
      case 'Trap Bar':
      case 'Landmine':
        return EquipmentType.barbell;
      case 'Cable':
        return EquipmentType.cable;
      case 'Bodyweight':
      case 'Medicine Ball':
      case 'Stability Ball':
        return EquipmentType.bodyweight;
      case 'Machine':
      case 'Smith Machine':
      case 'Plate-Loaded':
        return EquipmentType.machine;
      default:
        return EquipmentType.machine;
    }
  }
}
