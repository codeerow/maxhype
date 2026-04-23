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

    final primaryMuscleGroup = currentExercise.muscleGroups.isNotEmpty
        ? currentExercise.muscleGroups.first
        : MuscleGroup.chest;

    final allExercises = exerciseRepo
        .getExercisesByMuscleGroup(primaryMuscleGroup)
        .where((ex) => ex.id != currentExercise.id)
        .toList();

    final topExercises = allExercises.take(8).toList();
    final remainingExercises = allExercises.skip(8).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replace: ${currentExercise.name}',
              style: Theme.of(context).textTheme.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Filter: ${primaryMuscleGroup.displayName} exercises',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            color: AppTheme.textSecondary,
            height: 1,
            thickness: 0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (topExercises.isNotEmpty) ...[
            Text('TOP 8 POPULAR', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topExercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final exercise = topExercises[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pop();
                    onExerciseSelected(exercise);
                  },
                  child: ExerciseCard(exercise: exercise, onOptionsPressed: null),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final exercise = remainingExercises[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pop();
                    onExerciseSelected(exercise);
                  },
                  child: ExerciseCard(exercise: exercise, onOptionsPressed: null),
                );
              },
            ),
          ],
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
    );
  }
}
