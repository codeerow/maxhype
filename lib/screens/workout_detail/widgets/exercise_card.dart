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
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Exercise image with body atlas overlay - full height, no left padding
            SizedBox(
              width: 80,
              child: Stack(
                children: [
                  // Exercise image placeholder - full height
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.2),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        exercise.name[0],
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ),
                  ),
                  // Mini muscle atlas overlay in bottom-right corner
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: MiniMuscleAtlas(
                      muscleGroups: exercise.muscleGroups,
                    ),
                  ),
                ],
              ),
            ),
            // Exercise info with padding
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
            ),
            // 3-dots menu
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppTheme.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onOptionsPressed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
