import 'package:flutter/material.dart';

/// Wraps a scrollable so its top edge fades smoothly into the
/// translucent nav bar above it. Pair with `LiquidGlassNavOverlay`.
///
/// Two zones:
///   * `[0, fullyTransparentTop]` — status-bar area, fully invisible
///     (no content peeks above the safe area).
///   * `[fullyTransparentTop, fullyOpaqueAt]` — long gradient that
///     dissolves content under the floating glass bar.
///   * below `fullyOpaqueAt` — fully visible.
///
/// Per the design ref, the gradient stretches all the way through the
/// nav-bar band so letters / thumbnails read as "fading under glass"
/// rather than "cut behind a hard edge".
class FadeTopEdge extends StatelessWidget {
  final Widget child;

  /// Distance from the top where the gradient first allows content
  /// to be visible. Below this band content is hidden entirely.
  final double fullyTransparentTop;

  /// Distance from the top where content becomes fully opaque. Should
  /// land somewhere past the bottom edge of the nav bar so the bar's
  /// blur has something to refract before the cut becomes hard.
  final double fullyOpaqueAt;

  const FadeTopEdge({
    super.key,
    required this.child,
    this.fullyTransparentTop = 0,
    this.fullyOpaqueAt = kToolbarHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final total = rect.height;
        if (total <= 0) {
          return const LinearGradient(
            colors: [Colors.black, Colors.black],
          ).createShader(rect);
        }
        final hideStop = (fullyTransparentTop / total).clamp(0.0, 1.0);
        final showStop = (fullyOpaqueAt / total).clamp(hideStop, 1.0);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.transparent,
            Colors.black,
            Colors.black,
          ],
          stops: [0, hideStop, showStop, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}
