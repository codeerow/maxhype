enum MuscleGroup {
  // Upper Body - Push
  chest,
  shoulders,
  triceps,

  // Upper Body - Pull
  back,
  biceps,
  forearms,

  // Lower Body
  quads,
  hamstrings,
  glutes,
  calves,

  // Core
  abs,
  obliques,
  lowerBack,
}

extension MuscleGroupExtension on MuscleGroup {
  String get displayName {
    switch (this) {
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.triceps:
        return 'Triceps';
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.biceps:
        return 'Biceps';
      case MuscleGroup.forearms:
        return 'Forearms';
      case MuscleGroup.quads:
        return 'Quads';
      case MuscleGroup.hamstrings:
        return 'Hamstrings';
      case MuscleGroup.glutes:
        return 'Glutes';
      case MuscleGroup.calves:
        return 'Calves';
      case MuscleGroup.abs:
        return 'Abs';
      case MuscleGroup.obliques:
        return 'Obliques';
      case MuscleGroup.lowerBack:
        return 'Lower Back';
    }
  }
}
