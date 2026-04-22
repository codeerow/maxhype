import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../core/bloc_factory.dart';
import '../../models/workout.dart';
import '../../models/exercise.dart';
import 'bloc/workout_detail_bloc.dart';
import 'bloc/workout_detail_event.dart';
import 'bloc/workout_detail_state.dart';
import 'widgets/exercise_card.dart';
import 'widgets/exercise_options_sheet.dart';
import 'widgets/replace_exercise_sheet.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final Workout workout;

  const WorkoutDetailScreen({
    super.key,
    required this.workout,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final event = LoadWorkoutDetail(workout.id);
        return context.read<BlocFactory>().create<WorkoutDetailBloc>()
          ..add(event);
      },
      child: BlocBuilder<WorkoutDetailBloc, WorkoutDetailState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: _buildAppBar(context),
            body: switch (state) {
              WorkoutDetailLoading() => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange,
                  ),
                ),
              WorkoutDetailError(:final message) => Center(
                  child: Text(
                    'Error: $message',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              WorkoutDetailSuccess(:final workout) =>
                _buildContent(context, workout),
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        workout.title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      centerTitle: true,
      actions: const [],
    );
  }

  Widget _buildContent(BuildContext context, Workout workout) {
    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 100, // Space for sticky button
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Exercise button
              _buildAddExerciseButton(context),
              const SizedBox(height: 16),
              // Exercise count
              Text(
                '${workout.exercises.length} exercises',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              // Exercise list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workout.exercises.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final exercise = workout.exercises[index];
                  return ExerciseCard(
                    exercise: exercise,
                    onOptionsPressed: () => _showExerciseOptions(context, exercise),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // Floating bottom button
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: SafeArea(
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement start workout
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Start Workout - Coming soon!'),
                    backgroundColor: AppTheme.primaryOrange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.recoveryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
                shadowColor: AppTheme.recoveryGreen.withOpacity(0.5),
              ),
              child: const Text(
                'Start Workout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddExerciseButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement add exercise
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.primaryOrange.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              color: AppTheme.primaryOrange,
            ),
            const SizedBox(width: 8),
            Text(
              'Add Exercise',
              style: TextStyle(
                color: AppTheme.primaryOrange,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseOptions(BuildContext context, Exercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExerciseOptionsSheet(
        exercise: exercise,
        onReplaceExercise: () => _showReplaceExercise(context, exercise),
      ),
    );
  }

  void _showReplaceExercise(BuildContext context, Exercise currentExercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => ReplaceExerciseSheet(
        currentExercise: currentExercise,
        onExerciseSelected: (newExercise) {
          // Dispatch replace event to BLoC
          context.read<WorkoutDetailBloc>().add(
                ReplaceExercise(
                  workoutId: workout.id,
                  oldExerciseId: currentExercise.id,
                  newExercise: newExercise,
                ),
              );

          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Replaced with ${newExercise.name}'),
              backgroundColor: AppTheme.recoveryGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
