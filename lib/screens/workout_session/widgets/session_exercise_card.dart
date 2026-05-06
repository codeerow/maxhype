import 'package:flutter/material.dart';

import '../../../models/equipment_type.dart';
import '../../../models/session/session_exercise.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// Exercise card on the workout session main screen. Distinct from the
/// workout-detail ExerciseCard because the visual states (active accent / done
/// checkmark) and the subtitle format differ.
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

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final completed = ex.completed;
    final cardColor = widget.isActive
        ? AppTheme.cardBackgroundLifted
        : AppTheme.cardBackground;

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
      child: TapScale(
        scaleDown: 0.98,
        onTap: widget.onTap,
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildLeftAccent(completed),
              const SizedBox(width: 10),
              _buildThumb(ex),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ex.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(ex),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TapScale(
                scaleDown: 0.85,
                onTap: widget.onOptions,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Icon(
                    Icons.more_horiz,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftAccent(bool completed) {
    if (completed) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: _checkmarkController,
          curve: Curves.easeOutBack,
        ),
        child: Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(left: 8),
          decoration: const BoxDecoration(
            color: AppTheme.recoveryGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: widget.isActive ? 3 : 0,
      height: 56,
      margin: EdgeInsets.only(left: widget.isActive ? 6 : 0),
      decoration: BoxDecoration(
        color: AppTheme.activeOrange,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildThumb(SessionExercise ex) {
    final letter = ex.name.isNotEmpty ? ex.name[0].toUpperCase() : '?';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.thumbnailRedTint,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: AppTheme.recoveryRed,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _subtitle(SessionExercise ex) {
    final equipment = _equipmentLabel(ex.equipment);
    return '${ex.targetSets} sets · ${ex.loggedSetsCount} done · $equipment';
  }

  String _equipmentLabel(EquipmentType type) {
    return type.displayName;
  }
}
