import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/exercise.dart';
import '../../../models/muscle_group.dart';
import '../../../repositories/exercise_repository.dart';
import '../../../core/service_locator.dart';
import 'exercise_card.dart';

class ReplaceExerciseSheet extends StatelessWidget {
  final Exercise currentExercise;
  final Function(Exercise) onExerciseSelected;

  const ReplaceExerciseSheet({
    super.key,
    required this.currentExercise,
    required this.onExerciseSelected,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseRepo = getIt<ExerciseRepository>();

    // Get primary muscle group for filtering
    final primaryMuscleGroup = currentExercise.muscleGroups.isNotEmpty
        ? currentExercise.muscleGroups.first
        : MuscleGroup.chest;

    // Get all exercises for this muscle group
    final allExercises = exerciseRepo
        .getExercisesByMuscleGroup(primaryMuscleGroup)
        .where((ex) => ex.id != currentExercise.id) // Exclude current exercise
        .toList();

    // Top 8 popular
    final topExercises = allExercises.take(8).toList();

    // Remaining exercises
    final remainingExercises = allExercises.skip(8).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Replace: ${currentExercise.name}',
                                style: Theme.of(context).textTheme.headlineSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Filter: ${primaryMuscleGroup.displayName} exercises',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(
                color: AppTheme.textSecondary,
                height: 1,
                thickness: 0.5,
              ),
              // Exercise list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Top 8 Popular
                    if (topExercises.isNotEmpty) ...[
                      Text(
                        'TOP 8 POPULAR',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: topExercises.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final exercise = topExercises[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              onExerciseSelected(exercise);
                            },
                            child: ExerciseCard(
                              exercise: exercise,
                              onOptionsPressed: null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    // All exercises
                    if (remainingExercises.isNotEmpty) ...[
                      Text(
                        'ALL ${primaryMuscleGroup.displayName.toUpperCase()} EXERCISES',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: remainingExercises.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final exercise = remainingExercises[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              onExerciseSelected(exercise);
                            },
                            child: ExerciseCard(
                              exercise: exercise,
                              onOptionsPressed: null,
                            ),
                          );
                        },
                      ),
                    ],
                    // Empty state
                    if (allExercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No alternative exercises available',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
