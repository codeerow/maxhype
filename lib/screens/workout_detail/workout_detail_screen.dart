import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
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
import 'bloc/workout_preview_bloc.dart';
import 'widgets/exercise_card.dart';
import 'widgets/exercise_navigation.dart';
import '../workout_session/exercise_logging_screen.dart';
import '../workout_session/workout_session_screen.dart';
import '../workout_session/bloc/workout_session_bloc.dart';
import '../workout_session/bloc/workout_session_event.dart' as session_event;
import '../workout_session/bloc/workout_session_state.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final Workout workout;

  const WorkoutDetailScreen({
    super.key,
    required this.workout,
  });

  @override
  Widget build(BuildContext context) {
    // Detail screen owns the preview cubit — its lifetime matches this
    // route, so backing out without Start disposes the drafts (brief
    // Phase 3 Part 3 §6 — "If the user backs out without pressing
    // Start Workout, there should be no active session").
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final event = LoadWorkoutDetail(workout.id);
            return context.read<BlocFactory>().create<WorkoutDetailBloc>()
              ..add(event);
          },
        ),
        BlocProvider(create: (_) => WorkoutPreviewBloc()),
      ],
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
                    WorkoutDetailSuccess(
                      :final workout,
                      :final completionThisWeek,
                    ) =>
                      _buildContent(
                        context,
                        workout,
                        isCompletedThisWeek: completionThisWeek != null,
                      ),
                  },
                ),
                // Glass nav bar floats over the scroll body. Its shader
                // reads the backdrop directly from the framebuffer, so
                // the body MUST be painted first (below in the Stack).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
                    buildWhen: (prev, next) =>
                        (prev is SessionActive) != (next is SessionActive),
                    builder: (context, sessionState) {
                      // Per-workout Regenerate mirrors the web details
                      // header: a glass pill on the right, same style as
                      // the back pill. Hidden while ANY session is live —
                      // a card must never change under an active workout
                      // (identity / one-active-workout rules).
                      final sessionActive = sessionState is SessionActive;
                      return LiquidGlassNavBar(
                        title: Text(workout.title),
                        backIcon: CupertinoIcons.back,
                        onBack: () => Navigator.of(context).pop(),
                        actions: [
                          if (!sessionActive)
                            LiquidGlassNavAction(
                              icon: CupertinoIcons.arrow_2_circlepath,
                              iconColor: AppTheme.primaryOrange,
                              onTap: () {
                                context.read<WorkoutDetailBloc>().add(
                                  RegenerateWorkout(workout.id),
                                );
                                AppToast.show(context, 'Workout regenerated');
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Workout workout, {
    bool isCompletedThisWeek = false,
  }) {
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
                            // Brief §6 — tapping an exercise on the workout
                            // detail screen opens the preview variant of the
                            // logging screen, before any session is created.
                            onTap: () => _openPreview(context, exercise),
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
        // Floating bottom button — compact 80×32 pill centred along
        // the screen's horizontal axis.
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: SafeArea(
              child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
                buildWhen: (prev, next) {
                  bool isMine(WorkoutSessionState s) =>
                      s is SessionActive && s.session.workoutId == workout.id;
                  return isMine(prev) != isMine(next);
                },
                builder: (context, sessionState) {
                  if (isCompletedThisWeek) {
                    // Locked state for an already-finished workout in
                    // this ISO week (brief Item 7 follow-up). The screen
                    // is still browsable so the user can review what
                    // they logged — only the Start button is dimmed and
                    // non-interactive. Persists across navigation and
                    // restart because the bloc reloads completions from
                    // disk on `LoadWorkoutDetail`.
                    return Container(
                      width: 220,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: AppTheme.primaryOrange.withValues(
                              alpha: 0.85,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppTheme.primaryOrange.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return TapScale(
                    scaleDown: TapScalePreset.cta.scale,
                    enableHaptic: true,
                    onTap: () {
                      final sessionBloc = context.read<WorkoutSessionBloc>();
                      final cur = sessionBloc.state;
                      if (cur is SessionActive &&
                          cur.session.workoutId != workout.id) {
                        // Brief §4 — block the second-workout attempt
                        // with a premium-orange toast. Keeps the active
                        // session untouched and tells the user what to
                        // do, in the same visual language as the
                        // Completed / Cancelled toasts (clarifications
                        // 4.10, 4.11, 10.30).
                        AppToast.showPremium(
                          context,
                          'Finish your current workout first',
                          accent: AppTheme.primaryOrange,
                        );
                        return;
                      }
                      // Carry over any preview drafts the user typed
                      // before pressing Start — clarifications 6.15/6.18.
                      final drafts = Map.of(
                        context.read<WorkoutPreviewBloc>().state.drafts,
                      );
                      sessionBloc.add(
                        session_event.StartSession(
                          workout,
                          previewDrafts: drafts,
                        ),
                      );
                      Navigator.of(context).pushReplacement(
                        CupertinoPageRoute<void>(
                          builder: (_) => WorkoutSessionScreen.restored(),
                        ),
                      );
                    },
                    child: Container(
                      width: 220,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryOrange.withValues(
                              alpha: 0.45,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Start Workout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddExerciseButton(BuildContext context) {
    return TapScale(
      scaleDown: TapScalePreset.surface.scale,
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
      usedNames: workout.exercises.map((e) => e.name).toSet(),
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

  Future<void> _openPreview(
    BuildContext context,
    Exercise exercise,
  ) async {
    final sessionBloc = context.read<WorkoutSessionBloc>();
    final previewBloc = context.read<WorkoutPreviewBloc>();
    final detailBloc = context.read<WorkoutDetailBloc>();
    // Always pass the latest workout from the detail bloc — if the
    // user replaced an exercise from the options sheet, we want the
    // preview screen to read the updated template (clarification
    // 6.17).
    final detailState = detailBloc.state;
    final liveWorkout = detailState is WorkoutDetailSuccess
        ? detailState.workout
        : workout;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ExerciseLoggingScreen.preview(
          exerciseId: exercise.id,
          workout: liveWorkout,
          previewBloc: previewBloc,
          sessionBloc: sessionBloc,
          detailBloc: detailBloc,
        ),
      ),
    );
  }
}
