import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.exercise.completed ? 1.0 : 0.0,
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    if (widget.justCompleted) _checkmarkController.forward(from: 0.0);
    if (widget.justLogged) _glowController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant SessionExerciseCard old) {
    super.didUpdateWidget(old);
    if (!old.exercise.completed && widget.exercise.completed) {
      _checkmarkController.forward(from: 0.0);
    } else if (old.exercise.completed && !widget.exercise.completed) {
      _checkmarkController.value = 0.0;
    }
    if (widget.justCompleted && !old.justCompleted) {
      _checkmarkController.forward(from: 0.0);
    }
    if (widget.justLogged && !old.justLogged) {
      _glowController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _checkmarkController.dispose();
    _glowController.dispose();
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
        final glowStrength = _glowController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: glowStrength > 0
                ? [
                    BoxShadow(
                      color: AppTheme.activeOrange
                          .withValues(alpha: 0.25 * (1.0 - glowStrength)),
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
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppTheme.recoveryGreen,
            shape: BoxShape.circle,
          ),
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
