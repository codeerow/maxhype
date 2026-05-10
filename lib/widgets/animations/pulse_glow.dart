import 'package:flutter/material.dart';

/// Wraps [child] with a colored box-shadow that combines a constant base
/// glow and a one-shot pulse driven externally.
///
/// `pulseController` is owned by the caller — it just `.forward(from: 0)`s
/// when a pulse should fire. The widget reads the controller value and
/// renders a triangular envelope (0 → 1 → 0) so the pulse rises and decays
/// in one pass on top of the base.
///
/// Both the constant base and the pulse are clamped — passing 0 to either
/// disables that layer.
class PulseGlow extends StatelessWidget {
  final Widget child;
  final AnimationController pulseController;
  final Color color;

  /// Constant alpha of the base glow (0..1). Pass 0 to disable while the
  /// element is in its idle state, e.g., non-active card.
  final double baseAlpha;

  /// Peak alpha contributed by the pulse on top of [baseAlpha] (0..1).
  final double pulseAlpha;
  final double baseBlur;
  final double pulseExtraBlur;
  final double baseSpread;
  final double pulseExtraSpread;
  final BorderRadius? borderRadius;

  const PulseGlow({
    super.key,
    required this.child,
    required this.pulseController,
    required this.color,
    this.baseAlpha = 0.10,
    this.pulseAlpha = 0.22,
    this.baseBlur = 14,
    this.pulseExtraBlur = 6,
    this.baseSpread = 0.5,
    this.pulseExtraSpread = 1.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, _) {
        final t = pulseController.value;
        final envelope = (t == 0.0)
            ? 0.0
            : (1.0 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);

        final totalAlpha = baseAlpha + pulseAlpha * envelope;
        if (totalAlpha <= 0) return child;

        return Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: totalAlpha),
                blurRadius: baseBlur + pulseExtraBlur * envelope,
                spreadRadius: baseSpread + pulseExtraSpread * envelope,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
