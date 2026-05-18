import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Transient "🔥 NEW PR!! 🔥" capsule shown after a PR is logged.
///
/// `PrNewLabel.show(context)` overlays the label below the safe-area top
/// for ~1.4s: it drops in with a soft bounce, holds, then fades up. A
/// sweeping highlight runs across the surface for the duration so the
/// pill reads as "hot" rather than static text.
///
/// One label at a time — calling `show` again while a previous one is on
/// screen replaces it. Pure visual; haptic/audio are owned by the caller.
class PrNewLabel {
  static OverlayEntry? _current;

  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _current?.remove();
    final entry = OverlayEntry(
      builder: (_) => _PrNewLabelEntry(
        onDismissed: () {
          _current?.remove();
          _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _PrNewLabelEntry extends StatefulWidget {
  final VoidCallback onDismissed;

  const _PrNewLabelEntry({required this.onDismissed});

  @override
  State<_PrNewLabelEntry> createState() => _PrNewLabelEntryState();
}

class _PrNewLabelEntryState extends State<_PrNewLabelEntry>
    with TickerProviderStateMixin {
  // Total lifetime split: 0..0.18 drop-in, 0.18..0.78 hold, 0.78..1.0 fade-up.
  late final AnimationController _life;
  // Continuous shimmer that sweeps across the pill.
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _life = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _life.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDismissed();
    });

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _life.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      top: media.padding.top + 12,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: IgnorePointer(
          child: Center(
            child: AnimatedBuilder(
              animation: _life,
              builder: (context, child) {
                final t = _life.value;
                // Phase curves.
                final dropIn = (t / 0.18).clamp(0.0, 1.0);
                final fade = ((t - 0.78) / 0.22).clamp(0.0, 1.0);
                final easedIn = Curves.easeOutBack.transform(dropIn);
                final easedOut = Curves.easeInCubic.transform(fade);

                final opacity = (dropIn - easedOut).clamp(0.0, 1.0);
                // Offset: drops from -20 → 0, then drifts up to -14.
                final dy = -20 * (1 - easedIn) - 14 * easedOut;
                // Scale: overshoot from 0.85 → 1.0 with the back curve.
                final scale = 0.85 + 0.15 * easedIn - 0.04 * easedOut;

                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  ),
                );
              },
              child: _LabelPill(shimmer: _shimmer),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelPill extends StatelessWidget {
  final AnimationController shimmer;

  const _LabelPill({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (context, _) {
          // Move the highlight band from -0.4 → 1.4 so it sweeps fully
          // through the pill regardless of width.
          final s = shimmer.value;
          final pos = -0.4 + s * 1.8;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF7A1A),
                  Color(0xFFFFB066),
                  Color(0xFFFFD89E),
                  Color(0xFFFFB066),
                  Color(0xFFFF7A1A),
                ],
                stops: [0.0, 0.28, 0.5, 0.72, 1.0],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.65),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFFFFD89E).withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) {
                // Highlight: a soft white band passing left → right.
                final width = rect.width;
                final centerX = pos * width;
                final bandHalf = width * 0.18;
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Color(0x00FFFFFF),
                    Color(0x66FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: [
                    math.max(0.0, (centerX - bandHalf) / width),
                    (centerX / width).clamp(0.0, 1.0),
                    math.min(1.0, (centerX + bandHalf) / width),
                  ],
                ).createShader(rect);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔥', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'NEW PR!!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('🔥', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
