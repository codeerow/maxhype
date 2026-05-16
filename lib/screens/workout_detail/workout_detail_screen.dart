import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:progressive_blur/progressive_blur.dart';
import '../../theme/app_theme.dart';
import '../../core/bloc_factory.dart';
import '../../models/workout.dart';
import '../../models/exercise.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/fade_top_edge.dart';
import '../../widgets/liquid_glass_app_bar.dart';
import '../../widgets/tap_scale.dart';
import 'bloc/workout_detail_bloc.dart';
import 'bloc/workout_detail_event.dart';
import 'bloc/workout_detail_state.dart';
import 'widgets/exercise_card.dart';
import 'widgets/exercise_navigation.dart';
import '../workout_session/workout_session_screen.dart';
import '../workout_session/bloc/workout_session_bloc.dart';
import '../workout_session/bloc/workout_session_state.dart';

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
            body: Stack(
              children: [
                Positioned.fill(
                  child: switch (state) {
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
                ),
                // Glass nav bar floats over the scroll body. Its shader
                // reads the backdrop directly from the framebuffer, so
                // the body MUST be painted first (below in the Stack).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassNavBar(
                    title: Text(workout.title),
                    backIcon: CupertinoIcons.back,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Workout workout) {
    final statusBar = MediaQuery.of(context).padding.top;
    final navBottom = statusBar + kToolbarHeight;
    // Pixel height of the band where the progressive blur ramps from
    // max (at the top edge) down to zero. Slightly past the nav-bar
    // bottom so the smear tapers off softly into clear content.
    final blurBandPx = navBottom + 40;
    return Stack(
      children: [
        // Main content — scrolls underneath the floating glass nav bar.
        // Wrapped in ProgressiveBlurWidget so the top of the scroll is
        // smeared by a shader-driven gradient blur (per-pixel sigma
        // modulation), giving a seamless progression from sharp at the
        // bottom of the band to fully blurred at the very top. The
        // built-in BackdropFilter cannot do gradient sigma — masking
        // it with a ShaderMask silently disables the blur entirely
        // (Flutter issue #164079).
        LayoutBuilder(
          builder: (context, constraints) {
            // Convert the absolute blur-band pixel height into the
            // [0, 1] coordinate space the shader expects.
            final stop = (blurBandPx / constraints.maxHeight).clamp(0.0, 1.0);
            return ProgressiveBlurWidget(
              sigma: 22,
              linearGradientBlur: LinearGradientBlur(
                values: const [1, 0],
                stops: [0, stop],
                start: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              child: FadeTopEdge(
                fullyTransparentTop: 0,
                fullyOpaqueAt: navBottom + 40,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: navBottom + 8,
                    bottom: 100,
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
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final exercise = workout.exercises[index];
                  return ExerciseCard(
                    exercise: exercise,
                    onOptionsPressed: () =>
                        _showExerciseOptions(context, exercise),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
                  ),
                ),
              ),
            );
          },
        ),
        // Floating bottom button
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: SafeArea(
            child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
              buildWhen: (prev, next) {
                bool isMine(WorkoutSessionState s) =>
                    s is SessionActive && s.session.workoutId == workout.id;
                return isMine(prev) != isMine(next);
              },
              builder: (context, sessionState) {
                final inProgress = sessionState is SessionActive &&
                    sessionState.session.workoutId == workout.id;
                return TapScale(
                  scaleDown: 0.96,
                  enableHaptic: true,
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => inProgress
                            ? WorkoutSessionScreen.restored()
                            : WorkoutSessionScreen.start(workout: workout),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.recoveryGreen,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.recoveryGreen.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        inProgress ? 'Resume Workout' : 'Start Workout',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddExerciseButton(BuildContext context) {
    return TapScale(
      scaleDown: 0.97,
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
    showExerciseOptionsSheet(
      context,
      exercise: exercise,
      onReplace: (newExercise) {
        context.read<WorkoutDetailBloc>().add(
              ReplaceExercise(
                workoutId: workout.id,
                oldExerciseId: exercise.id,
                newExercise: newExercise,
              ),
            );
        AppToast.show(context, 'Replaced with ${newExercise.name}');
      },
    );
  }
}


