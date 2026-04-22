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
    final weightLb = (exercise.weight * 2.20462).round();
    final subtitle = '${exercise.sets} sets · ${exercise.reps} reps · $weightLb lb';

    return Row(
      children: [
        // Exercise image with muscle atlas overlay (bottom-left)
        SizedBox(
          width: 90,
          height: 116,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 90,
                  height: 116,
                  color: AppTheme.cardBackground,
                  child: Center(
                    child: Text(
                      exercise.name[0],
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: MiniMuscleAtlas(muscleGroups: exercise.muscleGroups),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                exercise.name,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // 3-dots in dark rounded container
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.more_horiz, color: AppTheme.textSecondary, size: 18),
            onPressed: onOptionsPressed,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
