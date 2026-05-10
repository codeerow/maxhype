import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/service_locator.dart';
import '../../../models/equipment_type.dart';
import '../../../models/exercise.dart';
import '../../../models/muscle_group.dart';
import '../../../models/session/session_exercise.dart';
import '../../../repositories/exercise_repository.dart';
import '../../../theme/app_theme.dart';
import '../../workout_detail/widgets/exercise_card.dart';

/// Wraps the workout-detail [ExerciseCard] to add session-only visuals:
///
///  - left accent bar when the exercise is the active one,
///  - left green checkmark when the exercise is completed (with scale-in),
///  - subtle glow pulse on return from logging (one-shot).
///
/// The card layout itself (thumbnail, MiniMuscleAtlas, name, ···) stays
/// identical to the workout detail screen — we just inject a `leadingAccent`
/// and override the subtitle.
class SessionExerciseCard extends StatefulWidget {
  final SessionExercise exercise;
  final bool isActive;

  /// True when this card just transitioned to completed; drives a one-shot
  /// scale-in checkmark animation.
  final bool justCompleted;

  /// True when this card just had a set logged; drives a one-shot subtle
  /// glow pulse on return from the logging screen.
  final bool justLogged;

  final VoidCallback onTap;
  final VoidCallback onOptions;

  const SessionExerciseCard({
    super.key,
    required this.exercise,
    required this.isActive,
    required this.justCompleted,
    required this.justLogged,
    required this.onTap,
    required this.onOptions,
  });

  @override
  State<SessionExerciseCard> createState() => _SessionExerciseCardState();
}

class _SessionExerciseCardState extends State<SessionExerciseCard>
    with TickerProviderStateMixin {
  late final AnimationController _checkmarkController;
  late final AnimationController _glowController;

  /// Subtle glow pulse fired when an exercise transitions to completed.
  /// Slightly longer than the active-card glow so it reads as "celebratory"
  /// rather than just confirmation.
  late final AnimationController _completionGlowController;

  /// Delay before the completion animation starts — gives the iOS-style
  /// Cupertino pop-transition (~350ms) time to finish, so the user actually
  /// sees the scale-in instead of it firing under the still-incoming screen.
  static const _completionDelay = Duration(milliseconds: 420);

  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      // If this card mounts already-completed (e.g., session restore), show
      // the checkmark in its final state without re-animating.
      value: widget.exercise.completed && !widget.justCompleted ? 1.0 : 0.0,
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _completionGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    if (widget.justCompleted) _scheduleCompletion();
    if (widget.justLogged) _glowController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant SessionExerciseCard old) {
    super.didUpdateWidget(old);

    // Catch the actual completed-flag flip first so a one-time animation +
    // medium haptic fires exactly once per transition.
    final justFlippedCompleted =
        !old.exercise.completed && widget.exercise.completed;

    if (justFlippedCompleted) {
      _scheduleCompletion();
    } else if (old.exercise.completed && !widget.exercise.completed) {
      _completionTimer?.cancel();
      _checkmarkController.value = 0.0;
      _completionGlowController.value = 0.0;
    }
    // Late state arrival edge case (justCompletedExerciseId arriving in a
    // separate state emit). Re-trigger to keep visuals snappy.
    if (widget.justCompleted &&
        !old.justCompleted &&
        !justFlippedCompleted) {
      _scheduleCompletion();
    }
    if (widget.justLogged && !old.justLogged) {
      _glowController.forward(from: 0.0);
    }
  }

  /// Defer the visual + haptic feedback until after the Cupertino pop
  /// transition has settled — otherwise the animation plays beneath the
  /// incoming session screen and is barely visible.
  void _scheduleCompletion() {
    _completionTimer?.cancel();
    _completionTimer = Timer(_completionDelay, () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _checkmarkController.forward(from: 0.0);
      _completionGlowController.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _checkmarkController.dispose();
    _glowController.dispose();
    _completionGlowController.dispose();
    super.dispose();
  }

  Exercise _resolveCatalogExercise(SessionExercise s) {
    final repo = getIt<ExerciseRepository>();
    final found = repo.getExerciseById(s.exerciseId);
    if (found != null) return found;
    // Fallback for an exercise not in the catalog (e.g., recently replaced).
    // The card needs `name` and `muscleGroups` for the MiniMuscleAtlas; sets
    // count comes from session, equipment is preserved from session snapshot.
    return Exercise(
      id: s.exerciseId,
      name: s.name,
      sets: s.targetSets,
      reps: 10,
      weight: 0,
      muscleGroups: const [MuscleGroup.chest],
      equipmentType: s.equipment,
      rating: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final catalogExercise = _resolveCatalogExercise(ex);
    final subtitle =
        '${ex.targetSets} sets · ${ex.loggedSetsCount} done · ${ex.equipment.displayName}';

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final orangeGlow = _glowController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: orangeGlow > 0
                ? [
                    BoxShadow(
                      color: AppTheme.activeOrange
                          .withValues(alpha: 0.25 * (1.0 - orangeGlow)),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.isActive
              ? AppTheme.cardBackgroundLifted
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ExerciseCard(
          exercise: catalogExercise,
          subtitleOverride: subtitle,
          leadingAccent: _buildLeadingAccent(),
          onTap: widget.onTap,
          onOptionsPressed: widget.onOptions,
        ),
      ),
    );
  }

  Widget? _buildLeadingAccent() {
    if (widget.exercise.completed) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: _checkmarkController,
          curve: Curves.easeOutBack,
        ),
        child: AnimatedBuilder(
          animation: _completionGlowController,
          builder: (context, child) {
            // Triangular envelope (0 → 1 → 0): the pulse rises and decays
            // in one pass, contained to the checkmark badge itself.
            final t = _completionGlowController.value;
            final pulse =
                (t == 0.0) ? 0.0 : (1.0 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.recoveryGreen,
                shape: BoxShape.circle,
                boxShadow: pulse > 0
                    ? [
                        BoxShadow(
                          color: AppTheme.recoveryGreen
                              .withValues(alpha: 0.55 * pulse),
                          blurRadius: 12 + 6 * pulse,
                          spreadRadius: 1 + 2 * pulse,
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: const Icon(Icons.check, color: Colors.white, size: 14),
        ),
      );
    }
    if (widget.isActive) {
      return Container(
        width: 3,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.activeOrange,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return null;
  }
}
