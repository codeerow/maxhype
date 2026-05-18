import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/haptic_manager.dart';
import '../../../core/service_locator.dart';
import '../../../models/equipment_type.dart';
import '../../../models/exercise.dart';
import '../../../models/muscle_group.dart';
import '../../../models/session/session_exercise.dart';
import '../../../repositories/exercise_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animations/animations.dart';
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

  /// True when the user has set a PR for this exercise during the current
  /// session — drives the persistent orange "PERSONAL RECORD" pill at the
  /// top of the card.
  final bool hasPr;

  final VoidCallback onTap;
  final VoidCallback onOptions;

  const SessionExerciseCard({
    super.key,
    required this.exercise,
    required this.isActive,
    required this.onTap,
    required this.onOptions,
    this.hasPr = false,
  });

  @override
  State<SessionExerciseCard> createState() => _SessionExerciseCardState();
}

class _SessionExerciseCardState extends State<SessionExerciseCard>
    with TickerProviderStateMixin, RouteAware {
  late final AnimationController _checkmarkController;
  late final AnimationController _glowController;

  /// Subtle glow pulse fired when an exercise transitions to completed.
  /// Slightly longer than the active-card glow so it reads as "celebratory"
  /// rather than just confirmation.
  late final AnimationController _completionGlowController;

  Timer? _completionTimer;
  Timer? _activePulseTimer;

  @override
  void initState() {
    super.initState();
    _checkmarkController = AnimationController(
      vsync: this,
      duration: AppDurations.scaleInPop,
      // Card mounts already-completed (e.g., session restore, re-entering
      // session screen): show the checkmark in its final state without
      // re-animating. Fresh completions are caught in `didUpdateWidget`.
      value: widget.exercise.completed ? 1.0 : 0.0,
    );
    _glowController = AnimationController(
      vsync: this,
      duration: AppDurations.pulseSoft,
    );
    _completionGlowController = AnimationController(
      vsync: this,
      duration: AppDurations.pulseCelebratory,
    );

    // Soft glow pulse on the active indicator whenever we appear on screen.
    if (widget.isActive && !widget.exercise.completed) {
      _scheduleActivePulse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      getIt<RouteObserver<PageRoute<dynamic>>>().subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // The logging screen was popped → session screen is visible again.
    // Re-fire the soft glow pulse on the active indicator per spec, but
    // wait for the Cupertino pop transition to settle.
    if (mounted &&
        widget.isActive &&
        !widget.exercise.completed) {
      _scheduleActivePulse();
    }
  }

  @override
  void didUpdateWidget(covariant SessionExerciseCard old) {
    super.didUpdateWidget(old);

    // The completed flag is the single source of truth. A fresh transition
    // false → true plays the scale-in pop, completion-glow pulse and a
    // medium haptic exactly once. The reverse (Undo / re-replace) resets.
    if (!old.exercise.completed && widget.exercise.completed) {
      _scheduleCompletion();
    } else if (old.exercise.completed && !widget.exercise.completed) {
      _completionTimer?.cancel();
      _checkmarkController.value = 0.0;
      _completionGlowController.value = 0.0;
    }
    // Pulse the active indicator when a card transitions into active state
    // (e.g., logging the first set on a new exercise). Same delay as the
    // on-appear pulse so it lands after the Cupertino transition settles.
    if (widget.isActive &&
        !widget.exercise.completed &&
        (!old.isActive || old.exercise.completed)) {
      _scheduleActivePulse();
    }
  }

  /// Defer the visual + haptic feedback until after the Cupertino pop
  /// transition has settled — otherwise the animation plays beneath the
  /// incoming session screen and is barely visible.
  void _scheduleCompletion() {
    _completionTimer?.cancel();
    _completionTimer = Timer(AppDurations.screenSettle, () {
      if (!mounted) return;
      getIt<HapticManager>().medium();
      _checkmarkController.forward(from: 0.0);
      _completionGlowController.forward(from: 0.0);
    });
  }

  /// Schedule a double soft-glow pulse on the active accent bar, delayed
  /// until after the Cupertino transition has settled. Two pulses read as
  /// a confident "I'm here" signal rather than a single quiet blink.
  void _scheduleActivePulse() {
    _activePulseTimer?.cancel();
    _activePulseTimer = Timer(AppDurations.screenSettle, () {
      if (!mounted) return;
      _playDoublePulse();
    });
  }

  Future<void> _playDoublePulse() async {
    if (!mounted) return;
    await _glowController.forward(from: 0.0);
    if (!mounted) return;
    await _glowController.forward(from: 0.0);
  }

  @override
  void dispose() {
    getIt<RouteObserver<PageRoute<dynamic>>>().unsubscribe(this);
    _completionTimer?.cancel();
    _activePulseTimer?.cancel();
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

    // The active-state pulse lives on the leading accent bar only — the
    // card itself just gets a subtle background lift while active.
    return Container(
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
        isPrAchieved: widget.hasPr,
        onTap: widget.onTap,
        onOptionsPressed: widget.onOptions,
      ),
    );
  }

  Widget? _buildLeadingAccent() {
    if (widget.exercise.completed) {
      // Scale-in pop + contained pulse-glow on the badge itself (no shadow
      // bleeding onto the rest of the card).
      return ScaleInPop(
        controller: _checkmarkController,
        child: PulseGlow(
          pulseController: _completionGlowController,
          color: AppTheme.recoveryGreen,
          baseAlpha: 0.0,
          pulseAlpha: 0.55,
          baseBlur: 0,
          pulseExtraBlur: 18,
          baseSpread: 0,
          pulseExtraSpread: 3,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppTheme.recoveryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
        ),
      );
    }
    if (widget.isActive) {
      // Vertical accent bar with constant "very light" glow + soft pulse
      // when the session screen becomes visible.
      return PulseGlow(
        pulseController: _glowController,
        color: AppTheme.activeOrange,
        baseAlpha: 0.35,
        pulseAlpha: 0.45,
        baseBlur: 6,
        pulseExtraBlur: 8,
        baseSpread: 0.5,
        pulseExtraSpread: 1.2,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: 3,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.activeOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }
    return null;
  }
}
