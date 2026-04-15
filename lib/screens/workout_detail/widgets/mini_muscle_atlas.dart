import 'package:flutter/material.dart';
import '../../../models/muscle_group.dart';
import '../../../theme/app_theme.dart';

class MiniMuscleAtlas extends StatelessWidget {
  final List<MuscleGroup> muscleGroups;

  const MiniMuscleAtlas({
    super.key,
    required this.muscleGroups,
  });

  IconData _getMuscleIcon() {
    if (muscleGroups.isEmpty) return Icons.fitness_center;

    // Return icon based on primary muscle group
    switch (muscleGroups.first) {
      case MuscleGroup.chest:
        return Icons.fitness_center;
      case MuscleGroup.shoulders:
        return Icons.accessibility_new;
      case MuscleGroup.triceps:
      case MuscleGroup.biceps:
        return Icons.trending_up;
      case MuscleGroup.back:
        return Icons.view_column;
      case MuscleGroup.forearms:
        return Icons.back_hand;
      case MuscleGroup.quads:
      case MuscleGroup.hamstrings:
      case MuscleGroup.calves:
        return Icons.directions_run;
      case MuscleGroup.glutes:
        return Icons.play_arrow;
      case MuscleGroup.abs:
      case MuscleGroup.obliques:
        return Icons.grid_3x3;
      case MuscleGroup.lowerBack:
        return Icons.arrow_back;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        _getMuscleIcon(),
        color: AppTheme.primaryOrange,
        size: 20,
      ),
    );
  }
}
