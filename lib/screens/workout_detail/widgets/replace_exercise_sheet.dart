import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/exercise.dart';
import '../../../models/muscle_group.dart';
import '../../../repositories/asset_exercise_repository.dart';
import '../../../repositories/exercise_repository.dart';
import '../../../repositories/fitness_plan_repository.dart';
import '../../../services/generator/replacement_ranker.dart';
import '../../../core/service_locator.dart';
import '../../../widgets/tap_scale.dart';
import 'replace_exercise_tile.dart';

class ReplaceExerciseSheet extends StatelessWidget {
  final Exercise currentExercise;
  final Function(Exercise) onExerciseSelected;

  /// Names of the other exercises already in the workout, excluded from the
  /// replacement pool so a swap can't duplicate an existing pick.
  final Set<String> usedNames;

  const ReplaceExerciseSheet({
    super.key,
    required this.currentExercise,
    required this.onExerciseSelected,
    this.usedNames = const {},
  });

  /// Ranks replacement candidates the same way the web prototype does:
  /// affinity to the original (movement pattern → category → muscle → …) and
  /// equipment continuity, not a plain muscle-group list. Falls back to the
  /// coarse muscle-group filter when the generator library isn't available
  /// (e.g. the exercise carries no generator metadata).
  Future<List<Exercise>> _rankedCandidates() async {
    // Prefer the full generator library; it carries the metadata affinity needs.
    final assetRepo = getIt.isRegistered<AssetExerciseRepository>()
        ? getIt<AssetExerciseRepository>()
        : null;

    if (assetRepo == null || currentExercise.generatorMeta == null) {
      return _coarseFallback();
    }

    final plan = await getIt<FitnessPlanRepository>().load();
    return const ReplacementRanker().rank(
      currentExercise,
      universe: assetRepo.getAllExercises(),
      alreadyUsed: usedNames,
      experience: plan.experience,
    );
  }

  /// Legacy behavior for exercises without generator metadata: everything in
  /// the same coarse muscle group, minus the current exercise.
  List<Exercise> _coarseFallback() {
    final exerciseRepo = getIt<ExerciseRepository>();
    final muscle = currentExercise.muscleGroups.isNotEmpty
        ? currentExercise.muscleGroups.first
        : MuscleGroup.chest;
    return exerciseRepo
        .getExercisesByMuscleGroup(muscle)
        .where(
          (ex) => ex.id != currentExercise.id && !usedNames.contains(ex.name),
        )
        .toList();
  }

  String get _filterLabel {
    final muscle = currentExercise.muscleGroups.isNotEmpty
        ? currentExercise.muscleGroups.first
        : MuscleGroup.chest;
    return muscle.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: TapScale(
          scaleDown: TapScalePreset.icon.scale,
          onTap: () => Navigator.of(context).pop(),
          child: const Center(
            child: Icon(
              CupertinoIcons.back,
              color: AppTheme.primaryOrange,
              size: 26,
            ),
          ),
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
              'Best matches for ${currentExercise.name}',
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
      body: FutureBuilder<List<Exercise>>(
        future: _rankedCandidates(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final allExercises = snapshot.data ?? const <Exercise>[];
          final topExercises = allExercises.take(8).toList();
          final remainingExercises = allExercises.skip(8).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              if (topExercises.isNotEmpty) ...[
                Text(
                  'BEST MATCHES',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topExercises.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final exercise = topExercises[index];
                    return ReplaceExerciseTile(
                      exercise: exercise,
                      onTap: () {
                        Navigator.of(context).pop();
                        onExerciseSelected(exercise);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (remainingExercises.isNotEmpty) ...[
                Text(
                  'ALL ${_filterLabel.toUpperCase()} EXERCISES',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: remainingExercises.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final exercise = remainingExercises[index];
                    return ReplaceExerciseTile(
                      exercise: exercise,
                      onTap: () {
                        Navigator.of(context).pop();
                        onExerciseSelected(exercise);
                      },
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
          );
        },
      ),
    );
  }
}
