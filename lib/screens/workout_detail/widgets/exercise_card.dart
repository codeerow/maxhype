import 'package:flutter/material.dart';
import '../../../models/exercise.dart';
import '../../../theme/app_theme.dart';
import 'mini_muscle_atlas.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onOptionsPressed;

  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onOptionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Exercise image with body atlas overlay
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              children: [
                // Exercise image placeholder
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      exercise.name[0],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ),
                // Mini muscle atlas overlay in bottom-right corner
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: MiniMuscleAtlas(
                    muscleGroups: exercise.muscleGroups,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Exercise info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.sets} sets',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 3-dots menu
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: AppTheme.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onOptionsPressed,
          ),
        ],
      ),
    );
  }
}
