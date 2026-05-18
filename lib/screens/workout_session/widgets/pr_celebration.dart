import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// One-shot row-anchored PR celebration. Wraps a child (the set row) and
/// renders two transient overlays on top of it when the externally-owned
/// [controller] runs `forward(from: 0)`:
///
///   1. A diagonal orange/gold shimmer sweeps left → right across the
///      row (~first 60% of the timeline).
///   2. A radial burst of small 🔥/✨ glyphs explodes from the row
///      centre and fades upward (~all 100%).
///
/// Both layers sit in IgnorePointer so they never block the tap targets
/// underneath. After [controller] reaches 1.0 the overlays paint nothing,
/// so it's safe to leave the widget in the tree.
class PrCelebration extends StatelessWidget {
  final Widget child;
  final AnimationController controller;

  const PrCelebration({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final t = controller.value;
                if (t == 0 || t >= 1) return const SizedBox.shrink();
                return CustomPaint(
                  painter: _ShimmerAndBurstPainter(t: t),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ShimmerAndBurstPainter extends CustomPainter {
  final double t;

  _ShimmerAndBurstPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    _paintShimmer(canvas, size);
    _paintBurst(canvas, size);
  }

  void _paintShimmer(Canvas canvas, Size size) {
    // Shimmer occupies roughly the first 60% of the timeline so the
    // burst gets clean air for the back half.
    if (t > 0.6) return;
    final localT = t / 0.6;
    final eased = Curves.easeInOut.transform(localT);

    final bandWidth = size.width * 0.35;
    final travel = size.width + bandWidth;
    final centerX = -bandWidth / 2 + travel * eased;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0x00FF8A3D),
        Color(0x66FFB066),
        Color(0xCCFFD89E),
        Color(0x66FFB066),
        Color(0x00FF8A3D),
      ],
      stops: [
        ((centerX - bandWidth) / size.width).clamp(0.0, 1.0),
        ((centerX - bandWidth / 2) / size.width).clamp(0.0, 1.0),
        (centerX / size.width).clamp(0.0, 1.0),
        ((centerX + bandWidth / 2) / size.width).clamp(0.0, 1.0),
        ((centerX + bandWidth) / size.width).clamp(0.0, 1.0),
      ],
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.plus;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      paint,
    );
  }

  void _paintBurst(Canvas canvas, Size size) {
    // Burst lives over the whole timeline so it tails past the shimmer.
    final center = Offset(size.width / 2, size.height / 2);
    const particles = 10;
    const maxRadius = 80.0;
    final eased = Curves.easeOutCubic.transform(t);

    for (var i = 0; i < particles; i++) {
      final angle = (i / particles) * math.pi * 2 + math.pi / particles;
      // Per-particle deterministic jitter: distance + glyph + fade phase.
      final distanceJitter = 0.7 + ((i * 13) % 30) / 100; // 0.70..0.99
      final glyphIdx = i % 2;
      final radius = maxRadius * distanceJitter * eased;
      final dx = center.dx + math.cos(angle) * radius;
      final dy = center.dy + math.sin(angle) * radius - eased * 16;
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final scale = 0.8 + 0.4 * eased;

      final tp = TextPainter(
        text: TextSpan(
          text: const ['🔥', '✨'][glyphIdx],
          style: TextStyle(
            fontSize: 14 * scale,
            color: Colors.white.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ShimmerAndBurstPainter old) => old.t != t;
}
