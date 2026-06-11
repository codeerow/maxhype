import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// Sticky rest-timer card displayed above the Log Set button on the logging
/// screen.
///
/// Source of truth is `endsAt` (wall-clock). We tick once per second to
/// re-render. On reaching zero we fade out the card and ring the boxing bell
/// (foreground only — see SessionAudio doc).
///
/// Part 2 boundaries documented here for the next milestone:
///   * Background timer: this widget pauses cleanly when the app is
///     backgrounded because Flutter pauses Timers; on resume the elapsed time
///     is recomputed from `endsAt` so no drift, but no notification fires
///     while the user is away.
///   * Notifications / foreground service / exact alarms / boot receivers
///     and battery-optimization prompts are deferred to Part 2.
class RestTimerCard extends StatefulWidget {
  final DateTime endsAt;
  final int totalSeconds;
  final VoidCallback onCancel;

  /// Shift the timer by this duration (e.g., -15s / +15s). When null, the
  /// adjust buttons are hidden.
  final ValueChanged<Duration>? onAdjust;

  const RestTimerCard({
    super.key,
    required this.endsAt,
    required this.totalSeconds,
    required this.onCancel,
    this.onAdjust,
  });

  @override
  State<RestTimerCard> createState() => _RestTimerCardState();
}

class _RestTimerCardState extends State<RestTimerCard>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _fadeOut;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _start();
  }

  void _start() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = widget.endsAt.difference(DateTime.now());
      if (remaining.inSeconds <= 0 && !_completed) {
        _completed = true;
        _ticker?.cancel();
        // The bloc owns the deadline: when its Timer fires it plays the
        // bell and dispatches CancelRestTimer, which clears
        // `activeRestEndsAt` and removes this card from the tree. The
        // card just plays its fade-out animation in the meantime; it
        // must NOT call onCompleted itself, or it can race ahead of the
        // bloc's Timer and cancel the bell before it fires.
        _fadeOut.reverse();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant RestTimerCard old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) {
      _completed = false;
      _fadeOut.value = 1.0;
      _start();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _fadeOut.dispose();
    super.dispose();
  }

  String _format(int s) {
    final mins = s ~/ 60;
    final secs = s % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(DateTime.now());
    final secs = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;

    return FadeTransition(
      opacity: _fadeOut,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.restCardTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primaryOrange.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Text(
                'REST',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (widget.onAdjust != null) ...[
                _AdjustButton(
                  label: '-15s',
                  onTap: () =>
                      widget.onAdjust!(const Duration(seconds: -15)),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                _format(secs),
                style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (widget.onAdjust != null) ...[
                const SizedBox(width: 10),
                _AdjustButton(
                  label: '+15s',
                  onTap: () => widget.onAdjust!(const Duration(seconds: 15)),
                ),
              ],
              const Spacer(),
              TapScale(
                scaleDown: TapScalePreset.icon.scale,
                onTap: widget.onCancel,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(
                    Icons.close,
                    size: 18,
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
}

/// Small "-15s" / "+15s" pill button shown either side of the rest count
/// for quick mid-rest adjustments.
class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: TapScalePreset.cta.scale,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.primaryOrange,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
