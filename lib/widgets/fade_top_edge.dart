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

  /// Shape of the alpha ramp between [fullyTransparentTop] and
  /// [fullyOpaqueAt]. 0.5 = linear. Values <0.5 push the midpoint
  /// upward, making the top of the band hide content faster (visually
  /// "darker fade"). Values >0.5 keep content visible longer.
  final double bias;

  const FadeTopEdge({
    super.key,
    required this.child,
    this.fullyTransparentTop = 0,
    this.fullyOpaqueAt = kToolbarHeight,
    this.bias = 0.5,
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
        // Midpoint inside [hideStop, showStop] biased toward the top
        // so the alpha ramp rises faster near the nav bar.
        final mid = hideStop + (showStop - hideStop) * bias.clamp(0.05, 0.95);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
            Colors.black,
            Colors.black,
          ],
          stops: [0, hideStop, mid, showStop, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}
