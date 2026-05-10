import 'package:flutter/material.dart';

/// One-shot scale-in pop animation driven by an externally-owned controller.
///
/// Designed for confirmation badges (e.g., the completed-exercise checkmark)
/// that need a small bounce-in feel. The caller drives the controller —
/// this keeps PulseGlow + ScaleInPop composable around the same animation.
class ScaleInPop extends StatelessWidget {
  final Widget child;
  final AnimationController controller;
  final Curve curve;

  const ScaleInPop({
    super.key,
    required this.child,
    required this.controller,
    this.curve = Curves.easeOutBack,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: controller, curve: curve),
      child: child,
    );
  }
}
