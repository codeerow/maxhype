import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Big celebratory "🔥 NEW PR!! 🔥" banner overlaid centered on the screen
/// when a logged set beats the previous best for its exercise.
///
/// Lives in an [Overlay] so it floats above any layout. Auto-dismisses
/// after a short hold.
class NewPrBanner {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required double weight,
    required int reps,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _current?.remove();

    final entry = OverlayEntry(
      builder: (_) => _BannerEntry(
        weight: weight,
        reps: reps,
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

class _BannerEntry extends StatefulWidget {
  final double weight;
  final int reps;
  final VoidCallback onDismissed;

  const _BannerEntry({
    required this.weight,
    required this.reps,
    required this.onDismissed,
  });

  @override
  State<_BannerEntry> createState() => _BannerEntryState();
}

class _BannerEntryState extends State<_BannerEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1400), () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatWeight(double w) {
    if (w == w.truncate()) return w.toInt().toString();
    return w.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeOutBack.transform(
              _controller.value.clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: _controller.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.7 + 0.3 * t,
                child: child,
              ),
            );
          },
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.45),
                    blurRadius: 32,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🔥  NEW PR!!  🔥',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatWeight(widget.weight)} lb × ${widget.reps}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
